/// Teknik analiz gösterge kataloğu — backend'deki
/// SmartFinance.Infrastructure/MarketData/IndicatorCatalog.cs ile key/isim/
/// kategori bazında birebir senkron tutulmalı.
class IndicatorDef {
  final String key;
  final String name;
  final String category;

  const IndicatorDef(this.key, this.name, this.category);
}

class IndicatorCatalog {
  static const List<IndicatorDef> all = [
    // ── Trend (fiyat grafiğine bindirilir) ──────────────────────────
    IndicatorDef('sma20', 'SMA (20)', 'trend'),
    IndicatorDef('sma50', 'SMA (50)', 'trend'),
    IndicatorDef('ema20', 'EMA (20)', 'trend'),
    IndicatorDef('ema50', 'EMA (50)', 'trend'),
    IndicatorDef('bollinger', 'Bollinger Bantları', 'trend'),
    IndicatorDef('keltner', 'Keltner Kanalları', 'trend'),
    IndicatorDef('donchian', 'Donchian Kanalları', 'trend'),
    IndicatorDef('supertrend', 'SuperTrend', 'trend'),
    IndicatorDef('psar', 'Parabolic SAR', 'trend'),
    IndicatorDef('vwap', 'VWAP', 'trend'),

    // ── Momentum (ayrı osilatör paneli) ──────────────────────────────
    IndicatorDef('rsi', 'RSI (14)', 'momentum'),
    IndicatorDef('macd', 'MACD (12,26,9)', 'momentum'),
    IndicatorDef('stoch', 'Stochastic Osilatör', 'momentum'),
    IndicatorDef('stochrsi', 'Stochastic RSI', 'momentum'),
    IndicatorDef('cci', 'CCI (20)', 'momentum'),
    IndicatorDef('williamsr', 'Williams %R', 'momentum'),
    IndicatorDef('roc', 'ROC (12)', 'momentum'),
    IndicatorDef('ultimate', 'Ultimate Osilatör', 'momentum'),
    IndicatorDef('awesome', 'Awesome Osilatör', 'momentum'),
    IndicatorDef('trix', 'TRIX (15)', 'momentum'),
    IndicatorDef('fisher', 'Fisher Transform', 'momentum'),
    IndicatorDef('tsi', 'True Strength Index', 'momentum'),

    // ── Trend Gücü ────────────────────────────────────────────────
    IndicatorDef('adx', 'ADX (14)', 'strength'),
    IndicatorDef('aroon', 'Aroon (25)', 'strength'),
    IndicatorDef('vortex', 'Vortex', 'strength'),

    // ── Volatilite ────────────────────────────────────────────────
    IndicatorDef('atr', 'ATR (14)', 'volatility'),
    IndicatorDef('stddev', 'Standart Sapma (20)', 'volatility'),

    // ── Hacim ─────────────────────────────────────────────────────
    IndicatorDef('obv', 'OBV', 'volume'),
    IndicatorDef('mfi', 'MFI (14)', 'volume'),
    IndicatorDef('cmf', 'Chaikin Para Akışı', 'volume'),
    IndicatorDef('adl', 'Birikim/Dağıtım', 'volume'),
    IndicatorDef('chaikinosc', 'Chaikin Osilatörü', 'volume'),
    IndicatorDef('forceindex', 'Force Index (13)', 'volume'),
  ];

  static const Set<String> defaultSelected = {'rsi', 'macd', 'bollinger'};

  static const List<String> categoryOrder = ['trend', 'momentum', 'strength', 'volatility', 'volume'];

  static const Map<String, String> categoryLabel = {
    'trend': 'Trend',
    'momentum': 'Momentum',
    'strength': 'Trend Gücü',
    'volatility': 'Volatilite',
    'volume': 'Hacim',
  };

  static IndicatorDef? byKey(String key) {
    for (final def in all) {
      if (def.key == key) return def;
    }
    return null;
  }
}
