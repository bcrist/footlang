/** @type LanguageFn */
export default function (hljs) {
  const LITERALS = {
    className: "literal",
    match: "(unreachable)",
  };

  const KEYWORDS =
    "and break catch defer distinct else error errordefer export fn for if nil or packed not " +
    "return struct match try union unreachable while until repeat error with only mut as in is";
  const TYPES = {
    className: "type",
    variants: [
      {
        // Integer Types
        match:
          "\\b(f16|f32|f64|f128|u\\d+(x\\d+)?|s\\d+(x\\d+)?|ssize|usize)\\b",
        relevance: 2,
      },
      {
        // Other Types
        match: "\\b(bool|cmp|any|mut)\\b",
        relevance: 0,
      },
    ],
  };

  const DECLARATIONS = {
    className: "variable",
    match: "\\b([a-zA-Z_][a-zA-Z_<>0-9]*|\\@\"[^\"]\")(?=\\s*:)",
    relevance: 0,
  };

  const BUILT_IN = {
    className: "built_in",
    match: "@[_a-zA-Z][_a-zA-Z0-9]*",
  };

  const BUILT_IN_TEST = {
    begin: "@import",
    relevance: 10,
  };

  const COMMENTTAGS = {
    className: "title",
    match: "\\b(TODO|NOTE)\\b:?",
    relevance: 0,
  };

  const COMMENTS = {
    className: "comment",
    variants: [
      {
        // Double Slash
        begin: "//",
        end: "$",
      },
    ],
    relevance: 0,
    contains: [COMMENTTAGS],
  };

  const STRINGCONTENT = {
    className: "string",
    variants: [
      {
        // escape
        match: "\\\\([nrt'\"\\\\]|(x[0-9a-fA-F]{2})|(u\\{[0-9a-fA-F]+\\}))",
      },
      {
        // invalid string escape
        match: "\\\\.",
      },
    ],
    relevance: 0,
  };
  const STRINGS = {
    className: "string",
    variants: [
      {
        // Double Quotes
        begin: '"',
        end: '"',
      },
      {
        // Multi-line
        begin: "\\\\\\\\",
        end: "$",
      },
    ],
    contains: [STRINGCONTENT],
    relevance: 0,
  };

  const OPERATORS = {
    className: "operator",
    variants: [
      {
        // Comparison
        match: "(==|<>)",
      },
      {
        // Arithmetic
        match: "(-|\\+|\\*|/)=?",
      },
      {
        // Bitwise
        match: "(&|\\|)=?",
      },
      {
        // Special
        match: "(\\+\\+|\\*\\*|->|=>)",
      },
    ],
    relevance: 0,
  };

  const FUNCTION = {
    className: "title.function",
    variants: [
      {
        match: "\\b\\'[a-zA-Z_][a-zA-Z0-9_<>]*\\'?\\b",
      },
      {
        match: "\\b[a-zA-Z_][a-zA-Z0-9_<>]*\\'\\b",
      },
    ],
    relevance: 0,
  };

  const NUMBERS = {
    className: "numbers",
    variants: [
      {
        // Decimal
        match: "\\b[0-9]([0-9._]*[0-9_])?\\b",
      },
      {
        // Decimal (explicit base)
        match: "\\b0_*[dD][0-9._]*[0-9_]\\b",
      },
      {
        // Hexadecimal
        match: "\\b0_*[xX][a-fA-F0-9._]*[a-fA-F0-9_]\\b",
      },
      {
        // Octal
        match: "\\b0_*[oO][0-7._]*[0-7_]\\b",
      },
      {
        // Quaternary
        match: "\\b0_*[qQ][0123._]*[0123_]\\b",
      },
      {
        // Binary
        match: "\\b0_*[bB][01._]*[01_]\\b",
      },
    ],
    relevance: 0,
  };

  const VERDI_DEFAULT_CONTAINS = [
    LITERALS,
    STRINGS,
    COMMENTS,
    TYPES,
    FUNCTION,
    BUILT_IN,
    BUILT_IN_TEST,
    OPERATORS,
    NUMBERS,
    DECLARATIONS,
  ];

  return {
    name: "Verdi",
    aliases: ["verdi"],
    keywords: KEYWORDS,
    contains: VERDI_DEFAULT_CONTAINS,
  };
}
