# Concedo CMP: Google Tag Manager template

A consent tag template for [Concedo](https://www.concedo.com.br), a consent management platform
for Brazilian websites (LGPD). It installs the Concedo banner through Google Tag Manager and
connects it to Google Consent Mode v2.

## What the tag does

1. Sets the default consent state with `setDefaultConsentState`, once per region row. Unless a
   row covers all regions, the global default is everything denied except `security_storage`.
2. Sets `ads_data_redaction`, `url_passthrough` and, when filled in, the developer ID.
3. For a returning visitor, reads the stored choice from the `concedo_consentimento` cookie and
   calls `updateConsentState` before any other tag fires.
4. Loads the Concedo script (`https://www.concedo.com.br/cmp/v1/loader.js`), which shows the
   banner. When the visitor chooses, or a stored choice stops being valid, the script calls the
   tag back and the tag calls `updateConsentState`.

| Consent type              | Concedo category | Default |
| ------------------------- | ---------------- | ------- |
| `ad_storage`              | Marketing        | denied  |
| `ad_user_data`            | Marketing        | denied  |
| `ad_personalization`      | Marketing        | denied  |
| `analytics_storage`       | Statistics       | denied  |
| `personalization_storage` | Personalization  | denied  |
| `functionality_storage`   | Necessary        | denied  |
| `security_storage`        | Necessary        | granted |

The Necessary category cannot be turned off, so `functionality_storage` and `security_storage`
are granted in every update.

## Fields

| Field                                   | Notes                                                                                                |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Site public key                         | Required. The key on the Implementation screen of the Concedo dashboard (starts with `pg_`).          |
| Default consent state by region         | Optional rows. Region is a comma-separated list of ISO 3166-2 codes; an empty region means all.       |
| Wait for update                         | Milliseconds Google tags wait for a stored choice. Default 500.                                       |
| Redact ads data                         | `ads_data_redaction`. On by default.                                                                  |
| Pass ad click information through URLs  | `url_passthrough`. Off by default; it can break checkouts that redirect.                              |
| Google developer ID                     | Optional. Empty means no `developer_id` is set.                                                       |

## Install

1. In Tag Manager, open **Templates › Tag Templates › Search Gallery**, find **Concedo CMP** and
   add it to the workspace.
2. Create a tag of this type, paste the site public key and choose the trigger
   **Consent Initialization - All Pages**. No other trigger runs early enough.
3. Remove any other tag that sets a consent default, and remove the Concedo script from the page
   `<head>` if it is there: use one installation only.
4. In every other tag, set the consent checks under **Advanced Settings › Consent Settings**.
   Custom HTML tags have no built-in checks and fire regardless of consent without them.
5. Preview, then publish.

## Contract with the Concedo script

Sandboxed JavaScript cannot set attributes on the script it injects and cannot listen to DOM
events, so the tag writes two globals before loading the script:

- `window.concedoGtmChave`: the site public key (replaces the `data-chave` attribute).
- `window.concedoGtmAoDecidir(decision)`: called by the script with
  `{ necessarios, estatisticas, marketing, personalizacao }` (booleans). While this function
  exists the script does not push `gtag('consent', ...)` commands to the dataLayer itself.

## License

Apache 2.0. See [LICENSE](LICENSE).
