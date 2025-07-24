module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "google",
  ],
  parserOptions: {
    ecmaVersion: 2021,
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "comma-dangle": "off",
    "no-multi-spaces": "off",
    "object-curly-spacing": "off",
    "quote-props": "off",
    "linebreak-style": ["error", "unix"],
    // other rules...


  },
};
