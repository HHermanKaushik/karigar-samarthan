require("dotenv").config();

const express = require("express");
const { twiml: { VoiceResponse } } = require("twilio");
const axios = require("axios");

const app = express();
app.use(express.urlencoded({ extended: true }));

// 🌍 Language Map
const LANGUAGES = {
  "1": { code: "hi-IN", name: "Hindi" },
  "2": { code: "en-IN", name: "English" },
  "3": { code: "mr-IN", name: "Marathi" },
  "4": { code: "bn-IN", name: "Bengali" },
  "5": { code: "ta-IN", name: "Tamil" }
};

// 🧠 Text Dictionary
const TEXT = {
  menu: {
    "en-IN": "Press 1 for orders, 2 for payments, 3 for shipping.",
    "hi-IN": "ऑर्डर के लिए 1 दबाएं, भुगतान के लिए 2, शिपिंग के लिए 3.",
    "mr-IN": "ऑर्डरसाठी 1 दाबा, पेमेंटसाठी 2, शिपिंगसाठी 3.",
    "bn-IN": "অর্ডারের জন্য 1 চাপুন, পেমেন্টের জন্য 2, শিপিংয়ের জন্য 3.",
    "ta-IN": "ஆர்டர்களுக்கு 1 அழுத்தவும், கட்டணத்திற்கு 2, ஷிப்பிங்கிற்கு 3."
  },
  invalid: {
    "en-IN": "Invalid input.",
    "hi-IN": "गलत चयन.",
    "mr-IN": "अवैध निवड.",
    "bn-IN": "ভুল নির্বাচন.",
    "ta-IN": "தவறான தேர்வு."
  }
};

// 🔤 Translation helper
function t(key, lang) {
  return TEXT[key]?.[lang] || TEXT[key]["en-IN"];
}

// 📞 ENTRY: Language selection
app.post("/ivr", (req, res) => {
  const twiml = new VoiceResponse();

  const gather = twiml.gather({
    numDigits: 1,
    action: "/set-language"
  });

  gather.say(
    "For Hindi press 1. For English press 2. For Marathi press 3. For Bengali press 4. For Tamil press 5."
  );

  res.type("text/xml");
  res.send(twiml.toString());
});

// 🌍 SET LANGUAGE
app.post("/set-language", (req, res) => {
  const twiml = new VoiceResponse();
  const choice = req.body.Digits;

  const lang = LANGUAGES[choice]?.code || "en-IN";

  const gather = twiml.gather({
    numDigits: 1,
    action: `/handle-input?lang=${lang}`
  });

  gather.say(t("menu", lang), { language: lang });

  res.type("text/xml");
  res.send(twiml.toString());
});

// 📊 HANDLE USER INPUT
app.post("/handle-input", async (req, res) => {
  const twiml = new VoiceResponse();
  const digit = req.body.Digits;
  const lang = req.query.lang || "en-IN";

  if (digit === "1") {
    const orders = await getOrders();
    twiml.say(
      translate(`You have ${orders.length} active orders`, lang),
      { language: lang }
    );
  } else if (digit === "2") {
    twiml.say(
      translate("Your pending payment is 2000 rupees", lang),
      { language: lang }
    );
  } else if (digit === "3") {
    twiml.say(
      translate("Ship your order to Delhi warehouse", lang),
      { language: lang }
    );
  } else {
    twiml.say(t("invalid", lang), { language: lang });
  }

  res.type("text/xml");
  res.send(twiml.toString());
});

// 🛒 WooCommerce API (basic)
async function getOrders() {
  try {
    const res = await axios.get(
      `${process.env.WC_URL}/wp-json/wc/v3/orders`,
      {
        auth: {
          username: process.env.WC_KEY,
          password: process.env.WC_SECRET
        }
      }
    );
    return res.data;
  } catch (err) {
    console.error("WC error:", err.message);
    return [];
  }
}

// 🌐 Translation (simple demo)
function translate(text, lang) {
  const translations = {
    "You have 0 active orders": {
      "hi-IN": "आपके पास कोई सक्रिय ऑर्डर नहीं है",
      "mr-IN": "तुमच्याकडे कोणतेही सक्रिय ऑर्डर नाहीत",
      "bn-IN": "আপনার কোনো সক্রিয় অর্ডার নেই",
      "ta-IN": "உங்களிடம் செயலில் உள்ள ஆர்டர்கள் இல்லை"
    },
    "Your pending payment is 2000 rupees": {
      "hi-IN": "आपका बकाया भुगतान 2000 रुपये है",
      "mr-IN": "तुमचे प्रलंबित पेमेंट 2000 रुपये आहे",
      "bn-IN": "আপনার বকেয়া পেমেন্ট 2000 টাকা",
      "ta-IN": "உங்கள் நிலுவை கட்டணம் 2000 ரூபாய்"
    },
    "Ship your order to Delhi warehouse": {
      "hi-IN": "अपने ऑर्डर को दिल्ली वेयरहाउस भेजें",
      "mr-IN": "तुमचा ऑर्डर दिल्ली वेअरहाउसला पाठवा",
      "bn-IN": "আপনার অর্ডার দিল্লি গুদামে পাঠান",
      "ta-IN": "உங்கள் ஆர்டரை டெல்லி கிடங்கிற்கு அனுப்புங்கள்"
    }
  };

  return translations[text]?.[lang] || text;
}

// 🚀 START SERVER
app.listen(process.env.PORT || 3000, () => {
  console.log("Server running...");
});
