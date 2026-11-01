import re

CATEGORY_KEYWORDS = {
    "Food": ["swiggy", "zomato", "dominos", "mcdonalds", "kfc", "starbucks", "cafe", "restaurant",
             "pizza", "burger", "blinkit", "zepto", "bigbasket", "instamart", "bakery", "dhaba"],
    "Travel": ["uber", "ola", "rapido", "irctc", "redbus", "makemytrip", "indigo", "air india",
               "metro", "petrol", "fuel", "fastag", "indian oil", "bharat petroleum"],
    "Shopping": ["amazon", "flipkart", "myntra", "ajio", "nykaa", "meesho", "decathlon",
                 "croma", "dmart", "reliance digital"],
    "Bills": ["electricity", "bescom", "airtel", "jio", "vodafone idea", "bsnl", "recharge",
              "broadband", "insurance", "lic", "gas", "postpaid"],
    "Rent": ["rent", "landlord", "nobroker", "society maintenance"],
    "Entertainment": ["netflix", "spotify", "hotstar", "prime video", "bookmyshow", "pvr",
                      "inox", "youtube premium", "steam"],
    "Health": ["pharmacy", "apollo", "medplus", "1mg", "pharmeasy", "netmeds", "practo",
               "hospital", "clinic", "diagnostics", "doctor"],
}
_RULES = [
    (cat, re.compile(r"\b(?:" + "|".join(re.escape(k) for k in kws) + r")\b", re.I))
    for cat, kws in CATEGORY_KEYWORDS.items()
]

try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
except ImportError:  # rules-only mode
    make_pipeline = None

MIN_SAMPLES = 20
MIN_CONFIDENCE = 0.6


def rule_category(text: str) -> str | None:
    for cat, rx in _RULES:
        if rx.search(text):
            return cat
    return None


class Categorizer:
    """Keyword rules first. For merchants the rules don't know, a small model
    trained on the user's own past transactions guesses the category."""

    def __init__(self, history: list[tuple[str, str]] | None = None):
        self.model = None
        data = [(m, c) for m, c in (history or []) if c != "Uncategorized"]
        if make_pipeline and len(data) >= MIN_SAMPLES and len({c for _, c in data}) >= 2:
            texts, labels = zip(*data)
            self.model = make_pipeline(
                TfidfVectorizer(analyzer="char_wb", ngram_range=(2, 4)),
                LogisticRegression(max_iter=1000),
            )
            self.model.fit(texts, labels)

    def categorize(self, merchant: str, description: str | None, txn_type: str) -> str:
        if txn_type == "credit":
            return "Income"
        cat = rule_category(f"{merchant} {description or ''}")
        if cat:
            return cat
        if self.model:
            probs = self.model.predict_proba([merchant])[0]
            best = probs.argmax()
            if probs[best] >= MIN_CONFIDENCE:
                return str(self.model.classes_[best])
        return "Uncategorized"