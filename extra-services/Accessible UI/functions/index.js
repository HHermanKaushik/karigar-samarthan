const functions = require("firebase-functions");
const axios = require("axios");

exports.testWoo = functions.https.onRequest(async (req, res) => {
  try {

    const consumerKey = "ck_e032198dba74f0dcb29465c666f15a39303758e5";
    const consumerSecret = "cs_86014fba07077c5c60e3248ad5a1dc6bd5393889";

    const wooUrl ='https://jstrust.in/wp-json/wc/v3/products' +
      `?consumer_key=${consumerKey}&consumer_secret=${consumerSecret}`;

    const {
      title,
      description,
      price
    } = req.body;

    const response = await axios.post(
      wooUrl,
      {
        name: title,
        description: description,
        regular_price: price,
        status: "publish"
      }
    );

    res.status(200).send(response.data);

  } catch (error) {

    console.error(error.response?.data || error.message);

    res.status(500).send(
      error.response?.data || error.message
    );
  }
});