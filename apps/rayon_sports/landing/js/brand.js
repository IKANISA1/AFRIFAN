(function () {
  const root = document.documentElement;

  const readSetting = (key, fallback) => {
    const value = root.dataset[key]?.trim();
    return value && value.length > 0 ? value : fallback;
  };

  const normalizeAmount = (raw) => {
    if (typeof raw === 'number' && Number.isFinite(raw)) return raw;
    const digits = Number.parseInt(String(raw ?? '').replace(/[^\d-]/g, ''), 10);
    return Number.isFinite(digits) ? digits : 0;
  };

  const branding = {
    currencyCode: readSetting('currencyCode', 'RWF'),
    currencySymbol: readSetting(
      'currencySymbol',
      readSetting('currencyCode', 'RWF'),
    ),
    currencyName: readSetting(
      'currencyName',
      readSetting('currencyCode', 'RWF'),
    ),
    normalizeAmount,
    formatCurrencyCode(amount) {
      return `${this.currencyCode} ${normalizeAmount(amount).toLocaleString()}`;
    },
    formatCurrencySymbol(amount) {
      return `${this.currencySymbol} ${normalizeAmount(amount).toLocaleString()}`;
    },
    formatMembershipPrice(amount) {
      return `${this.formatCurrencyCode(amount)} per month`;
    },
    hydrate() {
      document.querySelectorAll('[data-currency-code-text]').forEach((el) => {
        el.textContent = this.currencyCode;
      });

      document.querySelectorAll('[data-currency-symbol-text]').forEach((el) => {
        el.textContent = this.currencySymbol;
      });

      document.querySelectorAll('[data-currency-name-text]').forEach((el) => {
        el.textContent = this.currencyName;
      });

      document.querySelectorAll('[data-currency-code-amount]').forEach((el) => {
        el.textContent = this.formatCurrencyCode(el.dataset.currencyCodeAmount);
      });

      document.querySelectorAll('[data-currency-symbol-amount]').forEach((el) => {
        el.textContent = this.formatCurrencySymbol(
          el.dataset.currencySymbolAmount,
        );
      });

      document.querySelectorAll('[data-membership-price]').forEach((el) => {
        el.textContent = this.formatMembershipPrice(el.dataset.membershipPrice);
      });
    },
  };

  window.afriLandingBranding = branding;
  branding.hydrate();
})();
