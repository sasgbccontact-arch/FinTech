/// Modèle pays minimal : code ISO-2, nom FR (affichage), nom EN (requêtes GDELT),
/// drapeau emoji et région pour le regroupement UI.
class CountryInfo {
  final String iso2;
  final String nameFr;
  final String nameEn;
  final String flag;
  final String region;

  const CountryInfo({
    required this.iso2,
    required this.nameFr,
    required this.nameEn,
    required this.flag,
    required this.region,
  });
}

/// Pays groupés par région, dans l'ordre d'affichage.
const kCountriesByRegion = <String, List<CountryInfo>>{
  'Europe': [
    CountryInfo(iso2: 'FR', nameFr: 'France',          nameEn: 'France',               flag: '🇫🇷', region: 'Europe'),
    CountryInfo(iso2: 'DE', nameFr: 'Allemagne',        nameEn: 'Germany',              flag: '🇩🇪', region: 'Europe'),
    CountryInfo(iso2: 'GB', nameFr: 'Royaume-Uni',      nameEn: 'United Kingdom',       flag: '🇬🇧', region: 'Europe'),
    CountryInfo(iso2: 'IT', nameFr: 'Italie',           nameEn: 'Italy',                flag: '🇮🇹', region: 'Europe'),
    CountryInfo(iso2: 'ES', nameFr: 'Espagne',          nameEn: 'Spain',                flag: '🇪🇸', region: 'Europe'),
    CountryInfo(iso2: 'UA', nameFr: 'Ukraine',          nameEn: 'Ukraine',              flag: '🇺🇦', region: 'Europe'),
    CountryInfo(iso2: 'RU', nameFr: 'Russie',           nameEn: 'Russia',               flag: '🇷🇺', region: 'Europe'),
    CountryInfo(iso2: 'PL', nameFr: 'Pologne',          nameEn: 'Poland',               flag: '🇵🇱', region: 'Europe'),
    CountryInfo(iso2: 'NL', nameFr: 'Pays-Bas',         nameEn: 'Netherlands',          flag: '🇳🇱', region: 'Europe'),
    CountryInfo(iso2: 'BE', nameFr: 'Belgique',         nameEn: 'Belgium',              flag: '🇧🇪', region: 'Europe'),
    CountryInfo(iso2: 'CH', nameFr: 'Suisse',           nameEn: 'Switzerland',          flag: '🇨🇭', region: 'Europe'),
    CountryInfo(iso2: 'SE', nameFr: 'Suède',            nameEn: 'Sweden',               flag: '🇸🇪', region: 'Europe'),
    CountryInfo(iso2: 'NO', nameFr: 'Norvège',          nameEn: 'Norway',               flag: '🇳🇴', region: 'Europe'),
    CountryInfo(iso2: 'DK', nameFr: 'Danemark',         nameEn: 'Denmark',              flag: '🇩🇰', region: 'Europe'),
    CountryInfo(iso2: 'FI', nameFr: 'Finlande',         nameEn: 'Finland',              flag: '🇫🇮', region: 'Europe'),
    CountryInfo(iso2: 'PT', nameFr: 'Portugal',         nameEn: 'Portugal',             flag: '🇵🇹', region: 'Europe'),
    CountryInfo(iso2: 'AT', nameFr: 'Autriche',         nameEn: 'Austria',              flag: '🇦🇹', region: 'Europe'),
    CountryInfo(iso2: 'GR', nameFr: 'Grèce',            nameEn: 'Greece',               flag: '🇬🇷', region: 'Europe'),
    CountryInfo(iso2: 'CZ', nameFr: 'Rép. tchèque',     nameEn: 'Czech Republic',       flag: '🇨🇿', region: 'Europe'),
    CountryInfo(iso2: 'HU', nameFr: 'Hongrie',          nameEn: 'Hungary',              flag: '🇭🇺', region: 'Europe'),
    CountryInfo(iso2: 'RO', nameFr: 'Roumanie',         nameEn: 'Romania',              flag: '🇷🇴', region: 'Europe'),
    CountryInfo(iso2: 'SK', nameFr: 'Slovaquie',        nameEn: 'Slovakia',             flag: '🇸🇰', region: 'Europe'),
    CountryInfo(iso2: 'RS', nameFr: 'Serbie',           nameEn: 'Serbia',               flag: '🇷🇸', region: 'Europe'),
    CountryInfo(iso2: 'BY', nameFr: 'Biélorussie',      nameEn: 'Belarus',              flag: '🇧🇾', region: 'Europe'),
    CountryInfo(iso2: 'HR', nameFr: 'Croatie',          nameEn: 'Croatia',              flag: '🇭🇷', region: 'Europe'),
  ],
  'Amérique': [
    CountryInfo(iso2: 'US', nameFr: 'États-Unis',       nameEn: 'United States',        flag: '🇺🇸', region: 'Amérique'),
    CountryInfo(iso2: 'CA', nameFr: 'Canada',           nameEn: 'Canada',               flag: '🇨🇦', region: 'Amérique'),
    CountryInfo(iso2: 'MX', nameFr: 'Mexique',          nameEn: 'Mexico',               flag: '🇲🇽', region: 'Amérique'),
    CountryInfo(iso2: 'BR', nameFr: 'Brésil',           nameEn: 'Brazil',               flag: '🇧🇷', region: 'Amérique'),
    CountryInfo(iso2: 'AR', nameFr: 'Argentine',        nameEn: 'Argentina',            flag: '🇦🇷', region: 'Amérique'),
    CountryInfo(iso2: 'CO', nameFr: 'Colombie',         nameEn: 'Colombia',             flag: '🇨🇴', region: 'Amérique'),
    CountryInfo(iso2: 'VE', nameFr: 'Venezuela',        nameEn: 'Venezuela',            flag: '🇻🇪', region: 'Amérique'),
    CountryInfo(iso2: 'CL', nameFr: 'Chili',            nameEn: 'Chile',                flag: '🇨🇱', region: 'Amérique'),
    CountryInfo(iso2: 'PE', nameFr: 'Pérou',            nameEn: 'Peru',                 flag: '🇵🇪', region: 'Amérique'),
    CountryInfo(iso2: 'CU', nameFr: 'Cuba',             nameEn: 'Cuba',                 flag: '🇨🇺', region: 'Amérique'),
    CountryInfo(iso2: 'EC', nameFr: 'Équateur',         nameEn: 'Ecuador',              flag: '🇪🇨', region: 'Amérique'),
    CountryInfo(iso2: 'BO', nameFr: 'Bolivie',          nameEn: 'Bolivia',              flag: '🇧🇴', region: 'Amérique'),
  ],
  'Asie & Pacifique': [
    CountryInfo(iso2: 'CN', nameFr: 'Chine',            nameEn: 'China',                flag: '🇨🇳', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'JP', nameFr: 'Japon',            nameEn: 'Japan',                flag: '🇯🇵', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'IN', nameFr: 'Inde',             nameEn: 'India',                flag: '🇮🇳', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'KR', nameFr: 'Corée du Sud',     nameEn: 'South Korea',          flag: '🇰🇷', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'KP', nameFr: 'Corée du Nord',    nameEn: 'North Korea',          flag: '🇰🇵', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'ID', nameFr: 'Indonésie',        nameEn: 'Indonesia',            flag: '🇮🇩', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'PK', nameFr: 'Pakistan',         nameEn: 'Pakistan',             flag: '🇵🇰', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'VN', nameFr: 'Vietnam',          nameEn: 'Vietnam',              flag: '🇻🇳', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'TH', nameFr: 'Thaïlande',        nameEn: 'Thailand',             flag: '🇹🇭', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'MY', nameFr: 'Malaisie',         nameEn: 'Malaysia',             flag: '🇲🇾', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'PH', nameFr: 'Philippines',      nameEn: 'Philippines',          flag: '🇵🇭', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'TW', nameFr: 'Taïwan',           nameEn: 'Taiwan',               flag: '🇹🇼', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'SG', nameFr: 'Singapour',        nameEn: 'Singapore',            flag: '🇸🇬', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'AF', nameFr: 'Afghanistan',      nameEn: 'Afghanistan',          flag: '🇦🇫', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'MM', nameFr: 'Myanmar',          nameEn: 'Myanmar',              flag: '🇲🇲', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'BD', nameFr: 'Bangladesh',       nameEn: 'Bangladesh',           flag: '🇧🇩', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'AU', nameFr: 'Australie',        nameEn: 'Australia',            flag: '🇦🇺', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'NZ', nameFr: 'Nouvelle-Zélande', nameEn: 'New Zealand',          flag: '🇳🇿', region: 'Asie & Pacifique'),
    CountryInfo(iso2: 'KZ', nameFr: 'Kazakhstan',       nameEn: 'Kazakhstan',           flag: '🇰🇿', region: 'Asie & Pacifique'),
  ],
  'Turquie & Moyen-Orient': [
    CountryInfo(iso2: 'TR', nameFr: 'Turquie',          nameEn: 'Turkey',               flag: '🇹🇷', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'SA', nameFr: 'Arabie Saoudite',  nameEn: 'Saudi Arabia',         flag: '🇸🇦', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'IR', nameFr: 'Iran',             nameEn: 'Iran',                 flag: '🇮🇷', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'IL', nameFr: 'Israël',           nameEn: 'Israel',               flag: '🇮🇱', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'IQ', nameFr: 'Irak',             nameEn: 'Iraq',                 flag: '🇮🇶', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'SY', nameFr: 'Syrie',            nameEn: 'Syria',                flag: '🇸🇾', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'LB', nameFr: 'Liban',            nameEn: 'Lebanon',              flag: '🇱🇧', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'YE', nameFr: 'Yémen',            nameEn: 'Yemen',                flag: '🇾🇪', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'JO', nameFr: 'Jordanie',         nameEn: 'Jordan',               flag: '🇯🇴', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'QA', nameFr: 'Qatar',            nameEn: 'Qatar',                flag: '🇶🇦', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'AE', nameFr: 'Émirats arabes',   nameEn: 'United Arab Emirates', flag: '🇦🇪', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'KW', nameFr: 'Koweït',           nameEn: 'Kuwait',               flag: '🇰🇼', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'PS', nameFr: 'Palestine',        nameEn: 'Palestine',            flag: '🇵🇸', region: 'Turquie & Moyen-Orient'),
    CountryInfo(iso2: 'OM', nameFr: 'Oman',             nameEn: 'Oman',                 flag: '🇴🇲', region: 'Turquie & Moyen-Orient'),
  ],
  'Afrique': [
    CountryInfo(iso2: 'NG', nameFr: 'Nigeria',          nameEn: 'Nigeria',              flag: '🇳🇬', region: 'Afrique'),
    CountryInfo(iso2: 'ET', nameFr: 'Éthiopie',         nameEn: 'Ethiopia',             flag: '🇪🇹', region: 'Afrique'),
    CountryInfo(iso2: 'ZA', nameFr: 'Afrique du Sud',   nameEn: 'South Africa',         flag: '🇿🇦', region: 'Afrique'),
    CountryInfo(iso2: 'EG', nameFr: 'Égypte',           nameEn: 'Egypt',                flag: '🇪🇬', region: 'Afrique'),
    CountryInfo(iso2: 'KE', nameFr: 'Kenya',            nameEn: 'Kenya',                flag: '🇰🇪', region: 'Afrique'),
    CountryInfo(iso2: 'MA', nameFr: 'Maroc',            nameEn: 'Morocco',              flag: '🇲🇦', region: 'Afrique'),
    CountryInfo(iso2: 'DZ', nameFr: 'Algérie',          nameEn: 'Algeria',              flag: '🇩🇿', region: 'Afrique'),
    CountryInfo(iso2: 'TN', nameFr: 'Tunisie',          nameEn: 'Tunisia',              flag: '🇹🇳', region: 'Afrique'),
    CountryInfo(iso2: 'LY', nameFr: 'Libye',            nameEn: 'Libya',                flag: '🇱🇾', region: 'Afrique'),
    CountryInfo(iso2: 'SD', nameFr: 'Soudan',           nameEn: 'Sudan',                flag: '🇸🇩', region: 'Afrique'),
    CountryInfo(iso2: 'CD', nameFr: 'Congo (RDC)',       nameEn: 'Democratic Republic of Congo', flag: '🇨🇩', region: 'Afrique'),
    CountryInfo(iso2: 'GH', nameFr: 'Ghana',            nameEn: 'Ghana',                flag: '🇬🇭', region: 'Afrique'),
    CountryInfo(iso2: 'ML', nameFr: 'Mali',             nameEn: 'Mali',                 flag: '🇲🇱', region: 'Afrique'),
    CountryInfo(iso2: 'SN', nameFr: 'Sénégal',          nameEn: 'Senegal',              flag: '🇸🇳', region: 'Afrique'),
    CountryInfo(iso2: 'CM', nameFr: 'Cameroun',         nameEn: 'Cameroon',             flag: '🇨🇲', region: 'Afrique'),
    CountryInfo(iso2: 'TZ', nameFr: 'Tanzanie',         nameEn: 'Tanzania',             flag: '🇹🇿', region: 'Afrique'),
    CountryInfo(iso2: 'CI', nameFr: "Côte d'Ivoire",    nameEn: 'Ivory Coast',          flag: '🇨🇮', region: 'Afrique'),
  ],
};

/// Liste plate de tous les pays pour les recherches.
final kAllCountries = kCountriesByRegion.values
    .expand((list) => list)
    .toList();
