# 🚀 Deploy With Anonymized Data

Deploy a payment project with anonymized data for production and pre-production environments.

### Ideas

* Create a logical replica with the main db and a scheduler to open a transaction, anonymize and dump
  * This little guy will help: [pganonymize](https://github.com/rheinwerk-verlag/pganonymize)
  * Developing idea...
* Currently working on extension pg_anonymizer with pg-anon-scheduler service
