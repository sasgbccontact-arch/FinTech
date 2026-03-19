#!/usr/bin/env node
/**
 * Worker batch pour le système de duel hebdomadaire.
 *
 * Tâches :
 * - push ciblé des invitations en attente
 * - expiration des invitations après 48h
 * - notification des refus
 * - règlement des duels terminés
 * - notification des résultats
 *
 * Variables d'environnement :
 * FIREBASE_SERVICE_ACCOUNT  JSON string du compte de service
 * FIREBASE_PROJECT_ID       ID du projet Firebase
 */

import admin from 'firebase-admin';

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
const projectId = process.env.FIREBASE_PROJECT_ID;

if (!serviceAccountJson || !projectId) {
  console.error('[duels] FIREBASE_SERVICE_ACCOUNT ou FIREBASE_PROJECT_ID manquant.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  projectId,
});

const db = admin.firestore();
const messaging = admin.messaging();
const FieldValue = admin.firestore.FieldValue;
const quoteCache = new Map();
const minEligibleHoldingsValue = 10000;
const capitalTimelineSampleWindowMs = 6 * 60 * 60 * 1000;
const cliOptions = parseArgs(process.argv.slice(2));
const yahooBaseHeaders = {
  Accept: 'application/json',
  'Accept-Encoding': 'gzip, deflate',
  'Accept-Language': 'en-US,en;q=0.9,fr-FR;q=0.8',
  'User-Agent': 'Mozilla/5.0 (compatible; fintech-duel-worker/1.0)',
  Connection: 'keep-alive',
  Pragma: 'no-cache',
  'Cache-Control': 'no-cache',
};
let yahooCookie = null;
let yahooCrumb = null;
let yahooCookieExpiry = null;
const yahooCrumbRegex = /"CrumbStore":\\?\{"crumb":"([^"\\]*(?:\\.[^"\\]*)*)"/;

function parseArgs(args) {
  const options = {
    duelId: null,
    forceEnd: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = String(args[index] || '').trim();
    if (!arg) continue;
    if (arg === '--force-end') {
      options.forceEnd = true;
      continue;
    }
    if (arg === '--duel-id' && args[index + 1]) {
      options.duelId = String(args[index + 1]).trim();
      index += 1;
      continue;
    }
    if (arg.startsWith('--duel-id=')) {
      options.duelId = arg.slice('--duel-id='.length).trim();
    }
  }

  return options;
}

function asNumber(value, fallback = 0) {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function asTimestampDate(value) {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function relativeDiff(left, right) {
  const denom = Math.max(Math.abs(left), Math.abs(right), 1);
  return Math.abs(left - right) / denom;
}

function maxWeight(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  return holdings.reduce(
    (max, holding) => Math.max(max, holding.marketValue / holdingsValue),
    0,
  );
}

function marketZone(exchange, currency) {
  const merged = `${String(exchange || '').toUpperCase()} ${String(currency || '').toUpperCase()}`;
  if (merged.includes('PARIS') || merged.includes('EURONEXT') || merged.includes('EUR')) {
    return 'EU';
  }
  if (merged.includes('NASDAQ') || merged.includes('NYSE') || merged.includes('USD')) {
    return 'US';
  }
  if (merged.includes('TOKYO') || merged.includes('JPY')) {
    return 'JP';
  }
  if (merged.includes('HK') || merged.includes('HONG')) {
    return 'HK';
  }
  return merged.trim();
}

function structureBonus(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  let bonus = 0;
  if (holdings.length >= 5) {
    bonus += 2;
  } else if (holdings.length >= 3) {
    bonus += 1;
  }

  const concentration = maxWeight(holdings, holdingsValue);
  if (concentration <= 0.45) {
    bonus += 1;
  } else if (concentration <= 0.6) {
    bonus += 0.5;
  }

  const quoteTypes = new Set(
    holdings
      .map((holding) => String(holding.quoteType || '').trim().toUpperCase())
      .filter(Boolean),
  );
  if (quoteTypes.size >= 2) {
    bonus += 0.5;
  }

  const zones = new Set(
    holdings
      .map((holding) => marketZone(holding.exchange, holding.currency))
      .filter(Boolean),
  );
  if (zones.size >= 2) {
    bonus += 0.5;
  }

  return Math.min(Math.max(bonus, 0), 4);
}

function concentrationPenalty(holdings, holdingsValue) {
  if (!holdings.length || holdingsValue <= 0) return 0;
  const concentration = maxWeight(holdings, holdingsValue);
  if (concentration > 0.85) return 2;
  if (concentration > 0.7) return 1;
  return 0;
}

function deterministicIndex(seed, size) {
  if (size <= 0) return 0;
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = ((hash * 31) + seed.charCodeAt(i)) >>> 0;
  }
  return hash % size;
}

function updateYahooCookiesFromSetCookie(setCookieHeader) {
  if (!setCookieHeader || !String(setCookieHeader).trim()) return;
  const pairs = new Map();
  const source = String(setCookieHeader);

  if (yahooCookie) {
    for (const chunk of yahooCookie.split(';')) {
      const [rawName, ...rawValue] = chunk.split('=');
      const name = String(rawName || '').trim();
      const value = rawValue.join('=').trim();
      if (name && value) pairs.set(name, value);
    }
  }

  const cookieRegex = /(^|,)\s*([^=;\s,]+)=([^;,\s]+)/g;
  for (const match of source.matchAll(cookieRegex)) {
    const name = String(match[2] || '').trim();
    const value = String(match[3] || '').trim();
    if (!name || !value) continue;
    const lowered = name.toLowerCase();
    if (
      lowered === 'expires' ||
      lowered === 'path' ||
      lowered === 'domain' ||
      lowered === 'max-age' ||
      lowered === 'secure' ||
      lowered === 'httponly' ||
      lowered.startsWith('samesite')
    ) {
      continue;
    }
    pairs.set(name, value);
  }

  if (!pairs.size) return;
  yahooCookie = [...pairs.entries()]
    .map(([name, value]) => `${name}=${value}`)
    .join('; ');
  yahooCookieExpiry = new Date(Date.now() + (10 * 60 * 1000));
  yahooCrumb = null;
}

function buildYahooHeaders(extra = {}) {
  const headers = {...yahooBaseHeaders, ...extra};
  if (yahooCookie) {
    headers.Cookie = yahooCookie;
  }
  return headers;
}

function decodeYahooEscapedString(value) {
  if (!value) return '';
  try {
    return JSON.parse(`"${String(value).replace(/"/g, '\\"')}"`);
  } catch (_) {
    return String(value)
      .replace(/\\u002F/g, '/')
      .replace(/\\u0026/g, '&')
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\');
  }
}

function asMap(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
}

function extractRawNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (value && typeof value === 'object' && typeof value.raw === 'number' && Number.isFinite(value.raw)) {
    return value.raw;
  }
  return null;
}

function quoteReferer(symbol) {
  return `https://finance.yahoo.com/quote/${encodeURIComponent(symbol)}`;
}

function timestampFromUnixSeconds(value) {
  const numeric = asNumber(value, 0);
  return numeric > 0 ? new Date(numeric * 1000) : null;
}

function isoDateOrUnknown(value) {
  return value instanceof Date && !Number.isNaN(value.getTime())
    ? value.toISOString()
    : 'n/a';
}

function safeJsonParse(value) {
  try {
    return value ? JSON.parse(value) : null;
  } catch (_) {
    return null;
  }
}

async function bootstrapYahooCookies() {
  if (yahooCookie && yahooCookieExpiry && yahooCookieExpiry > new Date()) {
    return;
  }

  const targets = [
    {
      url: 'https://fc.yahoo.com',
      headers: {},
    },
    {
      url: 'https://finance.yahoo.com',
      headers: {
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    },
  ];

  for (const target of targets) {
    try {
      const response = await fetch(target.url, {
        headers: buildYahooHeaders(target.headers),
      });
      updateYahooCookiesFromSetCookie(response.headers.get('set-cookie'));
      if (yahooCookie) {
        return;
      }
    } catch (error) {
      console.warn(`[duels] Bootstrap Yahoo échoué ${target.url}:`, error.message);
    }
  }
}

async function getYahooQuoteHtml(symbol) {
  const encodedSymbol = encodeURIComponent(symbol);
  const targets = [
    `https://finance.yahoo.com/quote/${encodedSymbol}`,
    `https://finance.yahoo.com/quote/${encodedSymbol}?p=${encodedSymbol}&.tsrc=fin-srch`,
    `https://finance.yahoo.com/quote/${encodedSymbol}?guccounter=1`,
    `https://finance.yahoo.com/quote/${encodedSymbol}?.intl=us`,
  ];

  for (const url of targets) {
    try {
      const response = await fetch(url, {
        headers: buildYahooHeaders({
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          Referer: quoteReferer(symbol),
          'Upgrade-Insecure-Requests': '1',
        }),
      });
      updateYahooCookiesFromSetCookie(response.headers.get('set-cookie'));
      if (!response.ok) {
        continue;
      }
      const html = await response.text();
      if (html && html.length > 500) {
        return html;
      }
    } catch (error) {
      console.warn(`[duels] Quote HTML indisponible pour ${symbol} (${url}):`, error.message);
    }
  }

  throw new Error(`Quote HTML introuvable pour ${symbol}`);
}

async function collectCrumbFromHtml(symbol) {
  const html = await getYahooQuoteHtml(symbol);
  const match = yahooCrumbRegex.exec(html);
  if (!match?.[1]) {
    throw new Error(`Crumb Yahoo introuvable dans le HTML pour ${symbol}`);
  }
  const crumb = decodeYahooEscapedString(match[1]).trim();
  if (!crumb) {
    throw new Error(`Crumb Yahoo vide dans le HTML pour ${symbol}`);
  }
  yahooCrumb = crumb;
}

function extractEmbeddedYahooState(html) {
  const nextStart = html.indexOf('<script id="__NEXT_DATA__"');
  if (nextStart !== -1) {
    const openTagEnd = html.indexOf('>', nextStart);
    const closeTag = html.indexOf('</script>', openTagEnd + 1);
    if (openTagEnd !== -1 && closeTag !== -1) {
      const jsonText = html.slice(openTagEnd + 1, closeTag).trim();
      const parsed = safeJsonParse(jsonText);
      if (parsed) return parsed;
    }
  }

  const rootAppMatch = /root\.App\.main\s*=\s*(\{.*?\});\s*\n/s.exec(html);
  if (rootAppMatch?.[1]) {
    const parsed = safeJsonParse(rootAppMatch[1]);
    if (parsed) return parsed;
  }

  const apolloIndex = html.indexOf('window.__APOLLO_STATE__=');
  if (apolloIndex !== -1) {
    const start = apolloIndex + 'window.__APOLLO_STATE__='.length;
    const end = html.indexOf('</script>', start);
    if (end !== -1) {
      let snippet = html.slice(start, end).trim();
      if (snippet.endsWith(';')) {
        snippet = snippet.slice(0, -1);
      }
      const parsed = safeJsonParse(snippet);
      if (parsed) return parsed;
    }
  }

  return null;
}

function extractHtmlQuote(symbol, html) {
  const root = extractEmbeddedYahooState(html);
  const rootMap = asMap(root);
  let price = null;

  const context = asMap(rootMap?.context);
  const dispatcher = asMap(context?.dispatcher);
  const stores = asMap(dispatcher?.stores);
  const quoteSummaryStore = asMap(stores?.QuoteSummaryStore);
  price = asMap(quoteSummaryStore?.price);

  if (!price) {
    const quotePageStore = asMap(stores?.QuotePageStore);
    price = asMap(quotePageStore?.price);
  }

  if (!price) {
    const regexPrice =
      /"regularMarketPrice"\s*:\s*\{\s*"raw"\s*:\s*([-0-9.eE]+)|"regularMarketPrice"\s*:\s*([-0-9.eE]+)/.exec(html);
    const regexPrevClose =
      /"regularMarketPreviousClose"\s*:\s*\{\s*"raw"\s*:\s*([-0-9.eE]+)|"previousClose"\s*:\s*([-0-9.eE]+)/.exec(html);
    const displayNameMatch = /"longName"\s*:\s*"([^"]{1,200})"|"shortName"\s*:\s*"([^"]{1,200})"/.exec(html);
    const exchangeMatch = /"exchangeName"\s*:\s*"([^"]{1,120})"/.exec(html);
    const currencyMatch = /"currency"\s*:\s*"([A-Z]{3})"/.exec(html);
    const instrumentTypeMatch = /"instrumentType"\s*:\s*"([^"]{1,60})"/.exec(html);
    const marketPrice = asNumber(regexPrice?.[1] || regexPrice?.[2], 0);
    const previousClose = asNumber(regexPrevClose?.[1] || regexPrevClose?.[2], 0);
    const finalPrice = marketPrice || previousClose;
    if (finalPrice > 0) {
      return {
        marketPrice: finalPrice,
        displayName: decodeYahooEscapedString(displayNameMatch?.[1] || displayNameMatch?.[2] || symbol),
        exchange: decodeYahooEscapedString(exchangeMatch?.[1] || ''),
        currency: String(currencyMatch?.[1] || ''),
        quoteType: decodeYahooEscapedString(instrumentTypeMatch?.[1] || 'UNKNOWN'),
        source: marketPrice > 0 ? 'html_regularMarketPrice' : 'html_previousClose',
      };
    }
    throw new Error(`Prix HTML introuvable pour ${symbol}`);
  }

  const regularMarketPrice =
    extractRawNumber(price.regularMarketPrice) ??
    extractRawNumber(price.postMarketPrice) ??
    extractRawNumber(price.preMarketPrice);
  const previousClose =
    extractRawNumber(price.regularMarketPreviousClose) ??
    extractRawNumber(price.previousClose);
  const marketPrice = regularMarketPrice || previousClose || 0;
  if (marketPrice <= 0) {
    throw new Error(`Prix HTML introuvable pour ${symbol}`);
  }

  return {
    marketPrice,
    displayName: String(price.longName || price.shortName || symbol),
    exchange: String(price.exchangeName || price.fullExchangeName || price.exchange || ''),
    currency: String(price.currency || price.quoteCurrency || ''),
    quoteType: String(price.quoteType || price.instrumentType || 'UNKNOWN'),
    priceAt: timestampFromUnixSeconds(
      extractRawNumber(price.regularMarketTime) ?? extractRawNumber(price.postMarketTime),
    ),
    source: regularMarketPrice > 0 ? 'html_regularMarketPrice' : 'html_previousClose',
  };
}

async function fetchQuoteFromHtml(symbol) {
  const html = await getYahooQuoteHtml(symbol);
  return extractHtmlQuote(symbol, html);
}

async function refreshYahooCrumb(force = false, symbol = null) {
  const crumbValid =
    !force &&
    yahooCrumb &&
    yahooCookieExpiry &&
    yahooCookieExpiry > new Date();
  if (crumbValid) return;

  await bootstrapYahooCookies();
  if (!yahooCookie) {
    throw new Error('Yahoo cookie indisponible');
  }

  const response = await fetch('https://query1.finance.yahoo.com/v1/test/getcrumb', {
    headers: buildYahooHeaders({
      Accept: 'text/plain',
    }),
  });
  if (!response.ok) {
    if (symbol) {
      await collectCrumbFromHtml(symbol);
      return;
    }
    throw new Error(`Yahoo crumb -> HTTP ${response.status}`);
  }
  const crumb = String(await response.text()).trim();
  const crumbLooksValid = crumb && !crumb.includes('<') && crumb.length <= 64;
  if (!crumbLooksValid) {
    if (symbol) {
      await collectCrumbFromHtml(symbol);
      return;
    }
    throw new Error('Yahoo crumb vide');
  }
  yahooCrumb = crumb;
}

async function fetchQuoteFromEndpoint(symbol, endpoint) {
  await refreshYahooCrumb(false, symbol);
  const url =
    `https://${endpoint}.finance.yahoo.com/v7/finance/quote?symbols=${encodeURIComponent(symbol)}` +
    `&crumb=${encodeURIComponent(yahooCrumb)}`;
  const response = await fetch(url, {
    headers: buildYahooHeaders({
      Referer: quoteReferer(symbol),
    }),
  });
  updateYahooCookiesFromSetCookie(response.headers.get('set-cookie'));
  if (!response.ok) {
    throw new Error(`Yahoo ${symbol} ${endpoint} -> HTTP ${response.status}`);
  }
  const json = await response.json();
  const result = json?.quoteResponse?.result?.[0];
  if (!result) {
    throw new Error(`Quote introuvable pour ${symbol} via ${endpoint}`);
  }
  return {
    marketPrice: asNumber(result.regularMarketPrice, 0),
    displayName: String(result.longName || result.shortName || symbol),
    exchange: String(result.fullExchangeName || result.exchange || ''),
    currency: String(result.currency || ''),
    quoteType: String(result.quoteType || 'UNKNOWN'),
    priceAt: timestampFromUnixSeconds(result.regularMarketTime),
    source: endpoint,
  };
}

async function fetchChartPriceFromEndpoint(symbol, endpoint) {
  await refreshYahooCrumb(false, symbol);
  const url =
    `https://${endpoint}.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}` +
    `?range=1mo&interval=1d&includePrePost=false&events=div%2Csplits&crumb=${encodeURIComponent(yahooCrumb)}`;
  const response = await fetch(url, {
    headers: buildYahooHeaders({
      Referer: quoteReferer(symbol),
    }),
  });
  updateYahooCookiesFromSetCookie(response.headers.get('set-cookie'));
  if (!response.ok) {
    throw new Error(`Yahoo chart ${symbol} ${endpoint} -> HTTP ${response.status}`);
  }

  const json = await response.json();
  const result = json?.chart?.result?.[0];
  const meta = result?.meta || {};
  const timestamps = Array.isArray(result?.timestamp) ? result.timestamp : [];
  const closes = result?.indicators?.quote?.[0]?.close;
  let lastClose = 0;
  let lastCloseAt = null;
  if (Array.isArray(closes)) {
    for (let index = closes.length - 1; index >= 0; index -= 1) {
      const value = closes[index];
      if (typeof value === 'number' && Number.isFinite(value)) {
        lastClose = value;
        lastCloseAt = timestampFromUnixSeconds(timestamps[index]);
        break;
      }
    }
  }
  const regularMarketPrice = asNumber(meta.regularMarketPrice, 0);
  const marketState = String(meta.marketState || '').toUpperCase();
  const regularMarketTime = timestampFromUnixSeconds(meta.regularMarketTime);

  const marketPrice =
    (['REGULAR', 'PRE', 'POST', 'PREPRE', 'POSTPOST'].includes(marketState) &&
      regularMarketPrice > 0)
      ? regularMarketPrice
      : asNumber(lastClose, regularMarketPrice);

  if (!marketPrice || marketPrice <= 0) {
    throw new Error(`Derniere cloture introuvable pour ${symbol} via ${endpoint}`);
  }

  return {
    marketPrice,
    displayName: String(meta.longName || meta.shortName || symbol),
    exchange: String(meta.exchangeName || ''),
    currency: String(meta.currency || ''),
    quoteType: String(meta.instrumentType || 'UNKNOWN'),
    priceAt:
      ['REGULAR', 'PRE', 'POST', 'PREPRE', 'POSTPOST'].includes(marketState) &&
              regularMarketPrice > 0
          ? regularMarketTime
          : lastCloseAt,
    source:
      ['REGULAR', 'PRE', 'POST', 'PREPRE', 'POSTPOST'].includes(marketState) &&
              regularMarketPrice > 0
          ? `${endpoint}_chart_regularMarketPrice`
          : `${endpoint}_chart_lastClose`,
  };
}

async function fetchQuote(symbol) {
  const cached = quoteCache.get(symbol);
  if (cached) return cached;

  try {
    await bootstrapYahooCookies();
  } catch (error) {
    console.warn(`[duels] Bootstrap Yahoo impossible pour ${symbol}:`, error.message);
  }

  let lastError = null;
  for (const endpoint of ['query1', 'query2']) {
    try {
      const quote = await fetchQuoteFromEndpoint(symbol, endpoint);
      quoteCache.set(symbol, quote);
      return quote;
    } catch (error) {
      lastError = error;
      if (String(error.message || '').includes('HTTP 401')) {
        yahooCrumb = null;
        yahooCookieExpiry = null;
        try {
          await bootstrapYahooCookies();
          await refreshYahooCrumb(true, symbol);
        } catch (_) {}
      }
    }
  }

  for (const endpoint of ['query1', 'query2']) {
    try {
      const quote = await fetchChartPriceFromEndpoint(symbol, endpoint);
      quoteCache.set(symbol, quote);
      return quote;
    } catch (error) {
      lastError = error;
      if (String(error.message || '').includes('HTTP 401')) {
        yahooCrumb = null;
        yahooCookieExpiry = null;
        try {
          await bootstrapYahooCookies();
          await refreshYahooCrumb(true, symbol);
        } catch (_) {}
      }
    }
  }

  try {
    const quote = await fetchQuoteFromHtml(symbol);
    quoteCache.set(symbol, quote);
    return quote;
  } catch (error) {
    lastError = error;
  }

  throw lastError || new Error(`Quote introuvable pour ${symbol}`);
}

function serializeAuditHolding(holding) {
  return {
    symbol: holding.symbol,
    quantity: holding.quantity,
    averagePrice: holding.averagePrice,
    marketPrice: holding.marketPrice,
    marketValue: holding.marketValue,
    displayName: holding.displayName,
    exchange: holding.exchange,
    currency: holding.currency,
    quoteType: holding.quoteType,
    priceSource: holding.priceSource || 'unknown',
    priceAt: holding.priceAt ? admin.firestore.Timestamp.fromDate(holding.priceAt) : null,
  };
}

async function loadPortfolio(uid, {audit = false, auditLabel = ''} = {}) {
  const userRef = db.collection('users').doc(uid);
  const positionsRef = userRef.collection('games').doc('portofolio').collection('positions');
  const [userDoc, positionsSnap] = await Promise.all([userRef.get(), positionsRef.get()]);

  const reserveCoins = asNumber(userDoc.data()?.coins, 0);
  const holdings = [];

  for (const doc of positionsSnap.docs) {
    const data = doc.data();
    const symbol = String(data.symbol || doc.id || '').trim();
    const quantity = asNumber(data.quantity, 0);
    if (!symbol || quantity <= 0) continue;

    let quote;
    try {
      quote = await fetchQuote(symbol);
    } catch (error) {
      console.warn(`[duels] Quote indisponible pour ${symbol}:`, error.message);
      const storedRegularMarketPrice = asNumber(data.regularMarketPrice, 0);
      const storedMarketPrice = asNumber(data.marketPrice, 0);
      const averagePrice = asNumber(data.averagePrice, 0);
      const fallbackPrice =
        storedRegularMarketPrice || storedMarketPrice || averagePrice;
      const fallbackSource =
        storedRegularMarketPrice > 0
          ? 'stored_regularMarketPrice'
          : storedMarketPrice > 0
            ? 'stored_marketPrice'
            : 'averagePrice';
      quote = {
        marketPrice: fallbackPrice,
        displayName: String(data.displayName || symbol),
        exchange: String(data.exchange || ''),
        currency: String(data.currency || ''),
        quoteType: String(data.quoteType || 'UNKNOWN'),
        priceAt: asTimestampDate(data.lastUpdated) || asTimestampDate(data.updatedAt),
        source: fallbackSource,
      };
      console.warn(
        `[duels] Fallback prix ${symbol}: source=${fallbackSource} valeur=${fallbackPrice.toFixed(4)}`,
      );
    }

    const averagePrice = asNumber(data.averagePrice, 0);
    const marketPrice = quote.marketPrice || averagePrice;
    if (audit || (quote.source && quote.source !== 'query1')) {
      console.log(
        `[duels] Prix ${symbol}: source=${quote.source || 'unknown'} valeur=${marketPrice.toFixed(4)} qty=${quantity.toFixed(4)} marketValue=${(marketPrice * quantity).toFixed(4)} at=${isoDateOrUnknown(quote.priceAt)}${auditLabel ? ` audit=${auditLabel}` : ''}`,
      );
    }
    holdings.push({
      symbol,
      quantity,
      averagePrice,
      marketPrice,
      marketValue: marketPrice * quantity,
      displayName: quote.displayName || symbol,
      exchange: quote.exchange || '',
      currency: quote.currency || '',
      quoteType: quote.quoteType || 'UNKNOWN',
      priceSource: quote.source || 'unknown',
      priceAt: quote.priceAt || null,
      raw: data,
    });
  }

  const holdingsValue = holdings.reduce((sum, holding) => sum + holding.marketValue, 0);
  return {
    uid,
    reserveCoins,
    holdings,
    holdingsValue,
    totalCapital: holdingsValue + reserveCoins,
    positionsCount: holdings.length,
  };
}

function computeMetrics(portfolio, {startingTotalCapital, startingHoldingsValue}) {
  const investedCapitalBaseline =
    startingHoldingsValue > 0
      ? startingHoldingsValue
      : startingTotalCapital > 0
        ? startingTotalCapital
        : Math.max(portfolio.holdingsValue, 1);
  const pnl = portfolio.holdingsValue - investedCapitalBaseline;
  const returnPct = (pnl / Math.max(investedCapitalBaseline, 1)) * 100;
  const bonus = structureBonus(portfolio.holdings, portfolio.holdingsValue);
  const penalty = concentrationPenalty(portfolio.holdings, portfolio.holdingsValue);
  return {
    pureReturnPct: returnPct,
    returnPct,
    structureBonus: bonus,
    concentrationPenalty: penalty,
    persistentConcentrationPenalty: 0,
    finalScore: returnPct + bonus - penalty,
    maxPositionWeight: maxWeight(portfolio.holdings, portfolio.holdingsValue),
  };
}

function normalizeDayList(raw) {
  return Array.isArray(raw)
    ? [...new Set(raw.map((value) => String(value || '').trim()).filter(Boolean))].sort()
    : [];
}

function dayKey(date) {
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

function updateHighConcentrationDays(existing, {now, maxPositionWeight}) {
  const next = normalizeDayList(existing);
  if (maxPositionWeight >= 0.85) {
    const todayKey = dayKey(now);
    if (!next.includes(todayKey)) {
      next.push(todayKey);
    }
  }
  return next.slice(-14);
}

function persistentConcentrationPenaltyFromDays(count) {
  if (count >= 4) return 1.5;
  if (count >= 3) return 1.0;
  if (count >= 2) return 0.5;
  return 0;
}

function normalizeCapitalTimeline(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((entry) => ({
      at: asTimestampDate(entry?.at),
      totalCapital: asNumber(entry?.totalCapital, 0),
      score: asNumber(entry?.score, 0),
      returnPct: asNumber(entry?.returnPct, 0),
    }))
    .filter((entry) => entry.at)
    .sort((left, right) => left.at - right.at);
}

function appendCapitalTimeline(existing, {now, totalCapital, score, returnPct}) {
  const next = normalizeCapitalTimeline(existing);
  const point = {
    at: now,
    totalCapital,
    score,
    returnPct,
  };
  if (!next.length) {
    return [point];
  }

  const last = next[next.length - 1];
  const shouldReplace =
    (now.getTime() - last.at.getTime()) < capitalTimelineSampleWindowMs &&
    dayKey(now) === dayKey(last.at);

  if (shouldReplace) {
    next[next.length - 1] = point;
  } else {
    next.push(point);
  }

  return next.slice(-32).map((entry) => ({
    at: admin.firestore.Timestamp.fromDate(entry.at),
    totalCapital: entry.totalCapital,
    score: entry.score,
    returnPct: entry.returnPct,
  }));
}

function compareScores(left, right) {
  if (left.finalScore !== right.finalScore) return left.finalScore - right.finalScore;
  if (left.returnPct !== right.returnPct) return left.returnPct - right.returnPct;
  if (left.structureBonus !== right.structureBonus) return left.structureBonus - right.structureBonus;
  if (left.maxPositionWeight !== right.maxPositionWeight) {
    return right.maxPositionWeight - left.maxPositionWeight;
  }
  return 0;
}

function pickTransferredHolding(holdings, seed) {
  if (!holdings.length) return null;
  const sorted = [...holdings].sort((left, right) => left.symbol.localeCompare(right.symbol));
  return sorted[deterministicIndex(seed, sorted.length)];
}

async function loadTokensForUser(uid) {
  const snap = await db.collection('users').doc(uid).collection('devices').get();
  return [
    ...new Set(
      snap.docs
        .map((doc) => doc.data())
        .filter((data) => data.notificationsEnabled !== false)
        .map((data) => String(data.fcmToken || '').trim())
        .filter(Boolean),
    ),
  ];
}

async function pushToUser(uid, {title, body, data = {}}) {
  const tokens = await loadTokensForUser(uid);
  if (!tokens.length) {
    console.log(`[duels] Aucun token FCM actif pour ${uid}`);
    return;
  }

  await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data,
    apns: {
      headers: {
        'apns-push-type': 'alert',
        'apns-priority': '10',
      },
      payload: {
        aps: {sound: 'default'},
      },
    },
  });
}

function profileEligible(profileData) {
  return asNumber(profileData?.holdingsValueEstimate, 0) >= minEligibleHoldingsValue &&
    asNumber(profileData?.positionsCount, 0) >= 1;
}

async function processPendingRequests() {
  const now = new Date();
  const snap = await db.collection('duel_requests').where('status', '==', 'pending_response').limit(60).get();

  for (const doc of snap.docs) {
    const data = doc.data();
    const responseDeadline = asTimestampDate(data.responseDeadline);
    const requestId = doc.id;
    const initiatorUid = String(data.initiatorUid || '');
    const targetUid = String(data.targetUid || '');

    if (responseDeadline && responseDeadline <= now) {
      let canNotify = false;
      await db.runTransaction(async (transaction) => {
        const freshRequest = await transaction.get(doc.ref);
        if (!freshRequest.exists || freshRequest.data()?.status !== 'pending_response') {
          return;
        }

        const initiatorProfileRef = db.collection('duel_profiles').doc(initiatorUid);
        const targetProfileRef = db.collection('duel_profiles').doc(targetUid);
        const [initiatorProfileSnap, targetProfileSnap] = await Promise.all([
          transaction.get(initiatorProfileRef),
          transaction.get(targetProfileRef),
        ]);

        transaction.set(doc.ref, {
          status: 'expired',
          expiredAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        transaction.set(initiatorProfileRef, {
          state: 'idle',
          currentRequestId: null,
          eligible: profileEligible(initiatorProfileSnap.data()),
        }, {merge: true});

        transaction.set(targetProfileRef, {
          state: 'idle',
          currentRequestId: null,
          eligible: profileEligible(targetProfileSnap.data()),
        }, {merge: true});

        transaction.set(
          db.collection('users').doc(initiatorUid).collection('inbox').doc(`expired_${requestId}`),
          {
            type: 'duel_expired',
            title: 'Invitation expirée',
            body: 'Ton adversaire n’a pas répondu sous 48h. Tu peux relancer un duel.',
            createdAt: FieldValue.serverTimestamp(),
            requestId,
            duelId: null,
            actorUid: targetUid,
            isRead: false,
          },
          {merge: true},
        );

        canNotify = true;
      });

      if (canNotify) {
        await pushToUser(initiatorUid, {
          title: 'Invitation expirée',
          body: 'Ton adversaire n’a pas répondu à temps. Tu peux relancer un duel.',
          data: {type: 'duel_expired', requestId},
        }).catch((error) => {
          console.warn(`[duels] Push expiration ${requestId} impossible:`, error.message);
        });
        await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
      }
      continue;
    }

    if (!data.invitePushSentAt) {
      await pushToUser(targetUid, {
        title: 'Nouveau duel FinHub',
        body: `${data.initiatorSnapshot?.displayName || 'Un joueur'} te provoque en duel hebdo.`,
        data: {type: 'duel_invite', requestId},
      }).catch((error) => {
        console.warn(`[duels] Push invitation ${requestId} impossible:`, error.message);
      });
      await doc.ref.set({invitePushSentAt: FieldValue.serverTimestamp()}, {merge: true});
    }
  }
}

async function processRefusedRequests() {
  const snap = await db.collection('duel_requests').where('status', '==', 'refused').limit(40).get();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resolutionNotifiedAt) continue;
    const initiatorUid = String(data.initiatorUid || '');
    const targetName = data.targetSnapshot?.displayName || 'Ton adversaire';
    await pushToUser(initiatorUid, {
      title: 'Duel refusé',
      body: `${targetName} a refusé le duel. Tu peux relancer un matchmaking.`,
      data: {type: 'duel_refused', requestId: doc.id},
    }).catch((error) => {
      console.warn(`[duels] Push refus ${doc.id} impossible:`, error.message);
    });
    await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
}

async function processConvertedRequests() {
  const snap = await db.collection('duel_requests').where('status', '==', 'converted').limit(40).get();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resolutionNotifiedAt || !data.duelId) continue;

    const initiatorUid = String(data.initiatorUid || '');
    const targetUid = String(data.targetUid || '');
    const initiatorName = data.initiatorSnapshot?.displayName || 'Ton adversaire';
    const targetName = data.targetSnapshot?.displayName || 'Ton adversaire';

    await Promise.all([
      pushToUser(initiatorUid, {
        title: 'Duel lancé',
        body: `${targetName} a accepté le duel. Ouvre le dashboard pour suivre la semaine.`,
        data: {type: 'duel_started', duelId: String(data.duelId), requestId: doc.id},
      }).catch((error) => {
        console.warn(`[duels] Push démarrage initiateur ${doc.id} impossible:`, error.message);
      }),
      pushToUser(targetUid, {
        title: 'Duel lancé',
        body: `Le duel contre ${initiatorName} a commencé. Ouvre le dashboard pour suivre la semaine.`,
        data: {type: 'duel_started', duelId: String(data.duelId), requestId: doc.id},
      }).catch((error) => {
        console.warn(`[duels] Push démarrage cible ${doc.id} impossible:`, error.message);
      }),
    ]);

    await doc.ref.set({resolutionNotifiedAt: FieldValue.serverTimestamp()}, {merge: true});
  }
}

async function refreshActiveDuelSnapshots() {
  const snap = await db
    .collection('duels')
    .where('status', '==', 'active')
    .limit(30)
    .get();

  for (const doc of snap.docs) {
    await refreshSingleActiveDuelSnapshot(doc);
  }
}

async function refreshSingleActiveDuelSnapshot(doc) {
  const duel = doc.data();
  const participantIds = Array.isArray(duel.participants) ? duel.participants : [];
  if (participantIds.length !== 2) return;

  const participantRefs = participantIds.map((uid) => doc.ref.collection('participants').doc(uid));
  const participantSnaps = await Promise.all(participantRefs.map((ref) => ref.get()));
  const participantStates = Object.fromEntries(
    participantSnaps.map((snapItem, index) => [participantIds[index], snapItem.data() || {}]),
  );
  const portfolios = await Promise.all(participantIds.map((uid) => loadPortfolio(uid)));
  const portfolioByUid = Object.fromEntries(portfolios.map((portfolio) => [portfolio.uid, portfolio]));
  const now = new Date();

  await db.runTransaction(async (transaction) => {
    const freshDuel = await transaction.get(doc.ref);
    if (!freshDuel.exists || freshDuel.data()?.status !== 'active') {
      return;
    }

    const duel = doc.data();
    for (const uid of participantIds) {
      const state = participantStates[uid] || {};
      const portfolio = portfolioByUid[uid];
      const metrics = computeMetrics(portfolio, {
        startingTotalCapital: asNumber(state.startingTotalCapital, 0),
        startingHoldingsValue: asNumber(state.startingHoldingsValue, 0),
      });
      const highConcentrationDays = updateHighConcentrationDays(state.highConcentrationDays, {
        now,
        maxPositionWeight: metrics.maxPositionWeight,
      });
      const persistentPenalty = persistentConcentrationPenaltyFromDays(
        highConcentrationDays.length,
      );
      const adjustedScore =
        metrics.pureReturnPct +
        metrics.structureBonus -
        metrics.concentrationPenalty -
        persistentPenalty;
      const capitalTimeline = appendCapitalTimeline(state.capitalTimeline, {
        now,
        totalCapital: portfolio.holdingsValue,
        score: adjustedScore,
        returnPct: metrics.returnPct,
      });
      const teaserHolding = pickTransferredHolding(portfolio.holdings, `${doc.id}:${uid}`);

      transaction.set(doc.ref.collection('participants').doc(uid), {
        currentReturnPctCache: metrics.returnPct,
        currentScoreCache: adjustedScore,
        currentHoldingsValueCache: portfolio.holdingsValue,
        currentReserveCoinsCache: portfolio.reserveCoins,
        currentTotalCapitalCache: portfolio.holdingsValue,
        currentPositionsCountCache: portfolio.positionsCount,
        currentUpdatedAt: FieldValue.serverTimestamp(),
        teaserLine: teaserHolding || null,
        persistentConcentrationPenalty: persistentPenalty,
        highConcentrationDays,
        capitalTimeline,
      }, {merge: true});
    }
  });
}

async function settleDuel(doc) {
  const duel = doc.data();
  if (duel.status !== 'active') return false;
  const participantIds = Array.isArray(duel.participants) ? duel.participants : [];
  if (participantIds.length !== 2) {
    console.warn(`[duels] Duel ${doc.id} invalide: participants incomplets.`);
    return false;
  }

  const participantRefs = participantIds.map((uid) => doc.ref.collection('participants').doc(uid));
  const participantSnaps = await Promise.all(participantRefs.map((ref) => ref.get()));
  const participantStates = Object.fromEntries(
    participantSnaps.map((snap, index) => [participantIds[index], snap.data() || {}]),
  );
  const portfolios = await Promise.all(
    participantIds.map((uid) => loadPortfolio(uid, {audit: true, auditLabel: `settle:${doc.id}:${uid}`})),
  );
  const portfolioByUid = Object.fromEntries(portfolios.map((portfolio) => [portfolio.uid, portfolio]));

  const resultByUid = Object.fromEntries(
    participantIds.map((uid) => {
      const metrics = computeMetrics(portfolioByUid[uid], {
        startingTotalCapital: asNumber(participantStates[uid]?.startingTotalCapital, 0),
        startingHoldingsValue: asNumber(participantStates[uid]?.startingHoldingsValue, 0),
      });
      const highConcentrationDays = updateHighConcentrationDays(
        participantStates[uid]?.highConcentrationDays,
        {
          now: new Date(),
          maxPositionWeight: metrics.maxPositionWeight,
        },
      );
      const persistentPenalty = persistentConcentrationPenaltyFromDays(
        highConcentrationDays.length,
      );
      return [uid, {
        ...metrics,
        persistentConcentrationPenalty: persistentPenalty,
        finalScore:
          metrics.pureReturnPct +
          metrics.structureBonus -
          metrics.concentrationPenalty -
          persistentPenalty,
      }];
    }),
  );

  const [firstUid, secondUid] = participantIds;
  const left = resultByUid[firstUid];
  const right = resultByUid[secondUid];
  const comparison = compareScores(left, right);
  const winnerUid = comparison >= 0 ? firstUid : secondUid;
  const loserUid = winnerUid === firstUid ? secondUid : firstUid;
  const winnerPortfolio = portfolioByUid[winnerUid];
  const loserPortfolio = portfolioByUid[loserUid];
  const transferred = pickTransferredHolding(loserPortfolio.holdings, doc.id);

  let notifiedAfterSettlement = false;

  await db.runTransaction(async (transaction) => {
    const freshDuel = await transaction.get(doc.ref);
    if (!freshDuel.exists || freshDuel.data()?.status !== 'active') {
      return;
    }

    let rewardPosition = null;
    let lossPosition = null;

    if (transferred) {
      const loserPosRef = db
        .collection('users')
        .doc(loserUid)
        .collection('games')
        .doc('portofolio')
        .collection('positions')
        .doc(transferred.symbol);
      const winnerPosRef = db
        .collection('users')
        .doc(winnerUid)
        .collection('games')
        .doc('portofolio')
        .collection('positions')
        .doc(transferred.symbol);

      const loserPosSnap = await transaction.get(loserPosRef);
      if (loserPosSnap.exists) {
        const loserData = loserPosSnap.data() || {};
        const quantity = asNumber(loserData.quantity, transferred.quantity);
        const averagePrice = asNumber(loserData.averagePrice, transferred.averagePrice);
        rewardPosition = {
          symbol: transferred.symbol,
          displayName: transferred.displayName,
          quantity,
          averagePrice,
          marketPrice: transferred.marketPrice,
          exchange: transferred.exchange,
          currency: transferred.currency,
          quoteType: transferred.quoteType,
        };
        lossPosition = rewardPosition;

        const winnerPosSnap = await transaction.get(winnerPosRef);
        if (winnerPosSnap.exists) {
          const winnerData = winnerPosSnap.data() || {};
          const winnerQty = asNumber(winnerData.quantity, 0);
          const winnerAvg = asNumber(winnerData.averagePrice, averagePrice);
          const newQty = winnerQty + quantity;
          const newAvg = newQty <= 0 ? averagePrice : (((winnerQty * winnerAvg) + (quantity * averagePrice)) / newQty);
          transaction.set(winnerPosRef, {
            ...winnerData,
            symbol: transferred.symbol,
            quantity: newQty,
            averagePrice: newAvg,
            displayName: winnerData.displayName || transferred.displayName,
            exchange: winnerData.exchange || transferred.exchange,
            currency: winnerData.currency || transferred.currency,
            quoteType: winnerData.quoteType || transferred.quoteType,
            lastUpdated: FieldValue.serverTimestamp(),
          }, {merge: true});
        } else {
          transaction.set(winnerPosRef, {
            ...loserData,
            symbol: transferred.symbol,
            quantity,
            averagePrice,
            displayName: loserData.displayName || transferred.displayName,
            exchange: loserData.exchange || transferred.exchange,
            currency: loserData.currency || transferred.currency,
            quoteType: loserData.quoteType || transferred.quoteType,
            lastUpdated: FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        transaction.delete(loserPosRef);
      }
    }

    transaction.set(doc.ref, {
      status: 'settled',
      settledAt: FieldValue.serverTimestamp(),
      winnerUid,
      loserUid,
      resultAnimationReady: true,
    }, {merge: true});

    for (const uid of participantIds) {
      const metrics = resultByUid[uid];
      const portfolio = portfolioByUid[uid];
      transaction.set(doc.ref.collection('participants').doc(uid), {
        currentReturnPctCache: metrics.returnPct,
        currentScoreCache: metrics.finalScore,
        finalReturnPct: metrics.returnPct,
        finalScore: metrics.finalScore,
        structureBonus: metrics.structureBonus,
        concentrationPenalty: metrics.concentrationPenalty,
        persistentConcentrationPenalty: metrics.persistentConcentrationPenalty,
        currentHoldingsValueCache: portfolio.holdingsValue,
        currentReserveCoinsCache: portfolio.reserveCoins,
        currentTotalCapitalCache: portfolio.holdingsValue,
        result: uid === winnerUid ? 'win' : 'lose',
        rewardPosition: uid === winnerUid ? rewardPosition : null,
        lossPosition: uid === loserUid ? lossPosition : null,
      }, {merge: true});

      transaction.set(
        doc.ref.collection('audits').doc(uid),
        {
          uid,
          duelId: doc.id,
          settledAt: FieldValue.serverTimestamp(),
          result: uid === winnerUid ? 'win' : 'lose',
          startingHoldingsValue: asNumber(participantStates[uid]?.startingHoldingsValue, 0),
          startingTotalCapital: asNumber(participantStates[uid]?.startingTotalCapital, 0),
          currentHoldingsValue: portfolio.holdingsValue,
          currentTotalCapital: portfolio.totalCapital,
          currentReserveCoins: portfolio.reserveCoins,
          returnPct: metrics.returnPct,
          pureReturnPct: metrics.pureReturnPct,
          structureBonus: metrics.structureBonus,
          concentrationPenalty: metrics.concentrationPenalty,
          persistentConcentrationPenalty: metrics.persistentConcentrationPenalty,
          finalScore: metrics.finalScore,
          holdingsSnapshot: portfolio.holdings.map(serializeAuditHolding),
        },
        {merge: true},
      );
    }

    transaction.set(
      db.collection('users').doc(winnerUid).collection('inbox').doc(`duel_finished_${doc.id}`),
      {
        type: 'duel_finished',
        title: 'Défi terminé',
        body: 'Le duel est terminé. Ouvre le dashboard pour découvrir le verdict.',
        createdAt: FieldValue.serverTimestamp(),
        requestId: null,
        duelId: doc.id,
        actorUid: loserUid,
        isRead: false,
      },
      {merge: true},
    );
    transaction.set(
      db.collection('users').doc(loserUid).collection('inbox').doc(`duel_finished_${doc.id}`),
      {
        type: 'duel_finished',
        title: 'Défi terminé',
        body: 'Le duel est terminé. Ouvre le dashboard pour découvrir le verdict.',
        createdAt: FieldValue.serverTimestamp(),
        requestId: null,
        duelId: doc.id,
        actorUid: winnerUid,
        isRead: false,
      },
      {merge: true},
    );

    notifiedAfterSettlement = !freshDuel.data()?.resultNotifiedAt;
  });

  for (const uid of participantIds) {
    const state = participantStates[uid] || {};
    const metrics = resultByUid[uid];
    const portfolio = portfolioByUid[uid];
    console.log(
      `[duels] Score ${doc.id} uid=${uid} startInvested=${asNumber(state.startingHoldingsValue, 0).toFixed(2)} currentInvested=${portfolio.holdingsValue.toFixed(2)} reserve=${portfolio.reserveCoins.toFixed(2)} returnPct=${metrics.returnPct.toFixed(4)} bonus=${metrics.structureBonus.toFixed(2)} concentration=${metrics.concentrationPenalty.toFixed(2)} persistent=${metrics.persistentConcentrationPenalty.toFixed(2)} finalScore=${metrics.finalScore.toFixed(4)}`,
    );
    for (const holding of portfolio.holdings) {
      console.log(
        `[duels] Audit ${doc.id} uid=${uid} symbol=${holding.symbol} qty=${holding.quantity.toFixed(4)} price=${holding.marketPrice.toFixed(4)} value=${holding.marketValue.toFixed(4)} source=${holding.priceSource || 'unknown'} at=${isoDateOrUnknown(holding.priceAt)}`,
      );
    }
  }

  if (notifiedAfterSettlement) {
    await notifySettledDuel(doc.id, {
      winnerUid,
      loserUid,
    });
  }

  console.log(`[duels] Duel ${doc.id} settled winner=${winnerUid} loser=${loserUid}`);
  return true;
}

async function notifySettledDuel(
  duelId,
  {winnerUid, loserUid},
) {
  await Promise.all([
    pushToUser(winnerUid, {
      title: 'Duel terminé',
      body: 'Le duel est terminé. Ouvre FinHub pour découvrir le verdict.',
      data: {type: 'duel_finished', duelId},
    }).catch((error) => {
      console.warn(`[duels] Push résultat gagnant ${duelId} impossible:`, error.message);
    }),
    pushToUser(loserUid, {
      title: 'Duel terminé',
      body: 'Le duel est terminé. Ouvre FinHub pour découvrir le verdict.',
      data: {type: 'duel_finished', duelId},
    }).catch((error) => {
      console.warn(`[duels] Push résultat perdant ${duelId} impossible:`, error.message);
    }),
  ]);

  await db.collection('duels').doc(duelId).set({
    resultNotifiedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function retryPendingResultNotifications() {
  const snap = await db
    .collection('duels')
    .where('status', 'in', ['settled', 'reward_revealed'])
    .limit(30)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.resultNotifiedAt) continue;
    if (!data.winnerUid || !data.loserUid) continue;
    await notifySettledDuel(doc.id, {
      winnerUid: data.winnerUid,
      loserUid: data.loserUid,
    });
  }
}

async function processActiveDuels() {
  const now = new Date();
  const snap = await db
    .collection('duels')
    .where('status', '==', 'active')
    .where('endsAt', '<=', now)
    .limit(20)
    .get();

  for (const doc of snap.docs) {
    try {
      await settleDuel(doc);
    } catch (error) {
      console.error(`[duels] Erreur règlement ${doc.id}:`, error);
    }
  }
}

async function processSpecificDuel(duelId, {forceEnd = false} = {}) {
  const duelRef = db.collection('duels').doc(duelId);
  let duelSnap = await duelRef.get();
  if (!duelSnap.exists) {
    throw new Error(`Duel introuvable: ${duelId}`);
  }

  if (forceEnd) {
    const forcedEndAt = new Date(Date.now() - 1000);
    await duelRef.set({
      endsAt: admin.firestore.Timestamp.fromDate(forcedEndAt),
    }, {merge: true});
    console.log(`[duels] Duel ${duelId} forcé en fin de défi à ${forcedEndAt.toISOString()}`);
    duelSnap = await duelRef.get();
  }

  const duel = duelSnap.data() || {};
  if (duel.status === 'active') {
    await refreshSingleActiveDuelSnapshot(duelSnap);
    duelSnap = await duelRef.get();
    const refreshedDuel = duelSnap.data() || {};
    const endsAt = asTimestampDate(refreshedDuel.endsAt);
    if (!forceEnd && endsAt && endsAt > new Date()) {
      console.log(
        `[duels] Duel ${duelId} toujours actif jusqu’au ${endsAt.toISOString()}. Utilise --force-end pour le régler immédiatement.`,
      );
      return;
    }
    await settleDuel(duelSnap);
    return;
  }

  if ((duel.status === 'settled' || duel.status === 'reward_revealed') && duel.winnerUid && duel.loserUid) {
    if (!duel.resultNotifiedAt) {
      await notifySettledDuel(duelId, {
        winnerUid: duel.winnerUid,
        loserUid: duel.loserUid,
      });
    }
    console.log(`[duels] Duel ${duelId} déjà ${duel.status}.`);
    return;
  }

  console.log(`[duels] Duel ${duelId} dans l’état ${String(duel.status || 'inconnu')}, aucun règlement lancé.`);
}

async function main() {
  console.log('[duels] Début du worker duel');
  if (cliOptions.duelId) {
    await processSpecificDuel(cliOptions.duelId, {
      forceEnd: cliOptions.forceEnd,
    });
    console.log('[duels] Worker duel terminé (mode ciblé)');
    return;
  }
  await processPendingRequests();
  await processRefusedRequests();
  await processConvertedRequests();
  await refreshActiveDuelSnapshots();
  await processActiveDuels();
  await retryPendingResultNotifications();
  console.log('[duels] Worker duel terminé');
}

main().then(() => process.exit(0)).catch((error) => {
  console.error('[duels] Erreur fatale:', error);
  process.exit(1);
});
