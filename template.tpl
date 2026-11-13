___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Concedo CMP",
  "categories": ["TAG_MANAGEMENT", "UTILITY"],
  "brand": {
    "id": "brand_dummy",
    "displayName": "Concedo"
  },
  "description": "Installs the Concedo consent banner and connects it to Google Consent Mode v2: denied-by-default consent states (optionally per region) and consent updates when the visitor chooses.",
  "containerContexts": ["WEB"]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "publicKey",
    "displayName": "Site public key",
    "simpleValueType": true,
    "alwaysInSummary": true,
    "help": "The key shown on the Implementation screen of your Concedo dashboard (it starts with pg_).",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "PARAM_TABLE",
    "name": "defaultSettings",
    "displayName": "Default consent state by region",
    "help": "Optional. Each row sets the default consent state for the listed regions. A row with an empty Region is the global default. Without such a row the global default is everything denied except security_storage.",
    "newRowButtonText": "Add region",
    "paramTableColumns": [
      {
        "param": {
          "type": "TEXT",
          "name": "region",
          "displayName": "Region (comma-separated ISO 3166-2 codes; empty = all regions)",
          "simpleValueType": true
        },
        "isUnique": true
      },
      {
        "param": {
          "type": "SELECT",
          "name": "ad_storage",
          "displayName": "ad_storage",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "ad_user_data",
          "displayName": "ad_user_data",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "ad_personalization",
          "displayName": "ad_personalization",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "analytics_storage",
          "displayName": "analytics_storage",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "functionality_storage",
          "displayName": "functionality_storage",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "personalization_storage",
          "displayName": "personalization_storage",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "denied"
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "SELECT",
          "name": "security_storage",
          "displayName": "security_storage",
          "selectItems": [
            { "value": "denied", "displayValue": "Denied" },
            { "value": "granted", "displayValue": "Granted" }
          ],
          "simpleValueType": true,
          "defaultValue": "granted"
        },
        "isUnique": false
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "waitForUpdate",
    "displayName": "Wait for update",
    "simpleValueType": true,
    "valueUnit": "milliseconds",
    "defaultValue": 500,
    "help": "How long Google tags wait for the stored choice of a returning visitor before firing with the default state.",
    "valueValidators": [
      {
        "type": "NON_NEGATIVE_NUMBER"
      }
    ]
  },
  {
    "type": "CHECKBOX",
    "name": "adsDataRedaction",
    "checkboxText": "Redact ads data while ad_storage is denied",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "Sets ads_data_redaction: ad click identifiers are removed from requests while ad_storage is denied."
  },
  {
    "type": "CHECKBOX",
    "name": "urlPassthrough",
    "checkboxText": "Pass ad click information through URLs",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Sets url_passthrough. It can break checkouts that redirect, so test a purchase before enabling it."
  },
  {
    "type": "TEXT",
    "name": "developerId",
    "displayName": "Google developer ID (optional)",
    "simpleValueType": true,
    "help": "Leave empty unless Concedo support gave you a value."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const setDefaultConsentState = require('setDefaultConsentState');
const updateConsentState = require('updateConsentState');
const gtagSet = require('gtagSet');
const injectScript = require('injectScript');
const setInWindow = require('setInWindow');
const getCookieValues = require('getCookieValues');
const logToConsole = require('logToConsole');
const makeInteger = require('makeInteger');
const makeString = require('makeString');
const getType = require('getType');
const JSON = require('JSON');
const Object = require('Object');

const LOADER_URL = 'https://www.concedo.com.br/cmp/v1/loader.js';
const COOKIE_NAME = 'concedo_consentimento';
const DEFAULT_WAIT_FOR_UPDATE = 500;

// Banner category behind each consent type. functionality_storage and security_storage
// follow the "necessarios" category, which the visitor cannot turn off.
const SIGNAL_CATEGORY = {
  ad_storage: 'marketing',
  ad_user_data: 'marketing',
  ad_personalization: 'marketing',
  analytics_storage: 'estatisticas',
  functionality_storage: 'necessarios',
  personalization_storage: 'personalizacao',
  security_storage: 'necessarios'
};
// security_storage covers fraud prevention and login, which do not rely on consent.
const GLOBAL_DEFAULT = {
  ad_storage: 'denied',
  ad_user_data: 'denied',
  ad_personalization: 'denied',
  analytics_storage: 'denied',
  functionality_storage: 'denied',
  personalization_storage: 'denied',
  security_storage: 'granted'
};
const SIGNALS = Object.keys(SIGNAL_CATEGORY);

const parsedWait = makeInteger(data.waitForUpdate);
const waitForUpdate = parsedWait >= 0 ? parsedWait : DEFAULT_WAIT_FOR_UPDATE;

const regionsOf = (row) =>
  makeString(row.region || '')
    .split(',')
    .map((region) => region.trim().toUpperCase())
    .filter((region) => region);

const setDefault = (state, regions) => {
  const settings = {};
  SIGNALS.forEach((signal) => {
    settings[signal] = state[signal] === 'granted' ? 'granted' : 'denied';
  });
  if (regions.length) settings.region = regions;
  settings.wait_for_update = waitForUpdate;
  setDefaultConsentState(settings);
};

// Defaults go first, before anything that can fail. A consent type with no default counts
// as granted, so the denied global default is emitted whenever no row covers all regions.
const rows = data.defaultSettings || [];
if (rows.every((row) => regionsOf(row).length > 0)) setDefault(GLOBAL_DEFAULT, []);
rows.forEach((row) => setDefault(row, regionsOf(row)));

gtagSet({
  ads_data_redaction: data.adsDataRedaction === true,
  url_passthrough: data.urlPassthrough === true
});

const developerId = makeString(data.developerId || '').trim();
if (developerId) {
  const developerSetting = {};
  developerSetting['developer_id.' + developerId] = true;
  gtagSet(developerSetting);
}

const publicKey = makeString(data.publicKey || '').trim();
if (!publicKey) {
  // Without a key the Concedo script installs no banner, so nothing could withdraw a stored
  // choice: stay on the defaults and fail visibly.
  logToConsole('[Concedo] Site public key is empty: banner not installed.');
  return data.gtmOnFailure();
}

const applyDecision = (decision) => {
  if (getType(decision) !== 'object') return;
  const state = {};
  SIGNALS.forEach((signal) => {
    state[signal] = decision[SIGNAL_CATEGORY[signal]] ? 'granted' : 'denied';
  });
  updateConsentState(state);
};

// Returning visitor: the stored choice is applied here so the first tags of the page already
// see it. The Concedo script validates it once its configuration arrives and calls
// applyDecision again with everything denied if it no longer holds.
const cookies = getCookieValues(COOKIE_NAME);
const stored = cookies.length ? JSON.parse(cookies[0]) : undefined;
if (stored) applyDecision(stored.decisao);

// The Concedo script reads these two globals: the key (injectScript cannot set data-chave)
// and the function it calls with the visitor's decision instead of pushing gtag consent
// commands to the dataLayer itself.
setInWindow('concedoGtmChave', publicKey, true);
setInWindow('concedoGtmAoDecidir', applyDecision, true);

injectScript(LOADER_URL, data.gtmOnSuccess, data.gtmOnFailure, LOADER_URL);


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": { "publicId": "access_consent", "versionId": "1" },
      "param": [
        {
          "key": "consentTypes",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_user_data" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_personalization" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "analytics_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "functionality_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "personalization_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "security_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  },
  {
    "instance": {
      "key": { "publicId": "write_data_layer", "versionId": "1" },
      "param": [
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              { "type": 1, "string": "ads_data_redaction" },
              { "type": 1, "string": "url_passthrough" },
              { "type": 1, "string": "developer_id.*" }
            ]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  },
  {
    "instance": {
      "key": { "publicId": "inject_script", "versionId": "1" },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [{ "type": 1, "string": "https://www.concedo.com.br/cmp/v1/loader.js" }]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  },
  {
    "instance": {
      "key": { "publicId": "access_globals", "versionId": "1" },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "concedoGtmChave" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "concedoGtmAoDecidir" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  },
  {
    "instance": {
      "key": { "publicId": "get_cookies", "versionId": "1" },
      "param": [
        {
          "key": "cookieAccess",
          "value": { "type": 1, "string": "specific" }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [{ "type": 1, "string": "concedo_consentimento" }]
          }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  },
  {
    "instance": {
      "key": { "publicId": "logging", "versionId": "1" },
      "param": [
        {
          "key": "environments",
          "value": { "type": 1, "string": "debug" }
        }
      ]
    },
    "clientAnnotations": { "isEditedByUser": true },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Global default is denied except security_storage
  code: |-
    runCode(mockData);

    assertApi('setDefaultConsentState').wasCalledWith(globalDefault);
    assertThat(defaultCalls).hasLength(1);
    assertApi('updateConsentState').wasNotCalled();
    assertThat(injectedUrl).isEqualTo('https://www.concedo.com.br/cmp/v1/loader.js');
    assertThat(globals.concedoGtmChave).isEqualTo('pg_test_0123456789');
    assertApi('gtmOnSuccess').wasCalled();
- name: Region row sets its own default and keeps the denied global default
  code: |-
    mockData.defaultSettings = [{
      region: 'us-ca, US-NY',
      ad_storage: 'granted',
      ad_user_data: 'granted',
      ad_personalization: 'denied',
      analytics_storage: 'granted',
      functionality_storage: 'granted',
      personalization_storage: 'denied',
      security_storage: 'granted'
    }];
    mockData.waitForUpdate = '800';

    runCode(mockData);

    assertThat(defaultCalls).hasLength(2);
    assertApi('setDefaultConsentState').wasCalledWith({
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      security_storage: 'granted',
      wait_for_update: 800
    });
    assertApi('setDefaultConsentState').wasCalledWith({
      ad_storage: 'granted',
      ad_user_data: 'granted',
      ad_personalization: 'denied',
      analytics_storage: 'granted',
      functionality_storage: 'granted',
      personalization_storage: 'denied',
      security_storage: 'granted',
      region: ['US-CA', 'US-NY'],
      wait_for_update: 800
    });
- name: Row without region replaces the built-in global default
  code: |-
    mockData.defaultSettings = [{
      region: '',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'granted',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      security_storage: 'granted'
    }];

    runCode(mockData);

    assertThat(defaultCalls).hasLength(1);
    assertThat(defaultCalls[0].analytics_storage).isEqualTo('granted');
    assertThat(defaultCalls[0].region).isUndefined();
- name: Accept all sends a granted update
  code: |-
    runCode(mockData);
    globals.concedoGtmAoDecidir({
      necessarios: true,
      estatisticas: true,
      marketing: true,
      personalizacao: true
    });

    assertApi('updateConsentState').wasCalledWith({
      ad_storage: 'granted',
      ad_user_data: 'granted',
      ad_personalization: 'granted',
      analytics_storage: 'granted',
      functionality_storage: 'granted',
      personalization_storage: 'granted',
      security_storage: 'granted'
    });
- name: Reject all sends a denied update
  code: |-
    runCode(mockData);
    globals.concedoGtmAoDecidir({
      necessarios: true,
      estatisticas: false,
      marketing: false,
      personalizacao: false
    });

    assertApi('updateConsentState').wasCalledWith({
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'granted',
      personalization_storage: 'denied',
      security_storage: 'granted'
    });
- name: Stored choice of a returning visitor is applied before the script loads
  code: |-
    mock('getCookieValues', () => [
      '{"decisao":{"necessarios":true,"estatisticas":true,"marketing":false,"personalizacao":false},"acao":"personalizar"}'
    ]);
    mock('injectScript', () => {
      assertApi('updateConsentState').wasCalledWith({
        ad_storage: 'denied',
        ad_user_data: 'denied',
        ad_personalization: 'denied',
        analytics_storage: 'granted',
        functionality_storage: 'granted',
        personalization_storage: 'denied',
        security_storage: 'granted'
      });
      injectedUrl = 'injected';
    });

    runCode(mockData);

    assertThat(injectedUrl).isEqualTo('injected');
- name: Malformed cookie leaves the defaults in place
  code: |-
    mock('getCookieValues', () => ['not-json']);

    runCode(mockData);

    assertApi('updateConsentState').wasNotCalled();
    assertApi('injectScript').wasCalled();
- name: Empty developer ID does not set developer_id
  code: |-
    runCode(mockData);

    assertThat(gtagSetCalls).hasLength(1);
    assertApi('gtagSet').wasCalledWith({
      ads_data_redaction: true,
      url_passthrough: false
    });
- name: Developer ID is set when filled in
  code: |-
    mockData.developerId = 'dTESTID';
    mockData.urlPassthrough = true;

    runCode(mockData);

    assertThat(gtagSetCalls).hasLength(2);
    assertThat(gtagSetCalls[0].url_passthrough).isTrue();
    assertThat(gtagSetCalls[1]['developer_id.dTESTID']).isTrue();
- name: Empty key fails without injecting the script
  code: |-
    mockData.publicKey = '';
    mock('getCookieValues', () => [
      '{"decisao":{"necessarios":true,"estatisticas":true,"marketing":true,"personalizacao":true}}'
    ]);

    runCode(mockData);

    assertApi('setDefaultConsentState').wasCalledWith(globalDefault);
    assertApi('updateConsentState').wasNotCalled();
    assertApi('injectScript').wasNotCalled();
    assertApi('setInWindow').wasNotCalled();
    assertApi('gtmOnFailure').wasCalled();
    assertApi('gtmOnSuccess').wasNotCalled();
setup: |-
  const mockData = {
    publicKey: 'pg_test_0123456789',
    waitForUpdate: '500',
    adsDataRedaction: true,
    urlPassthrough: false,
    developerId: ''
  };
  const globalDefault = {
    ad_storage: 'denied',
    ad_user_data: 'denied',
    ad_personalization: 'denied',
    analytics_storage: 'denied',
    functionality_storage: 'denied',
    personalization_storage: 'denied',
    security_storage: 'granted',
    wait_for_update: 500
  };
  let injectedUrl;
  const globals = {};
  const defaultCalls = [];
  const gtagSetCalls = [];
  mock('setDefaultConsentState', (settings) => {
    defaultCalls.push(settings);
  });
  mock('gtagSet', (settings) => {
    gtagSetCalls.push(settings);
  });
  mock('getCookieValues', () => []);
  mock('setInWindow', (key, value) => {
    globals[key] = value;
    return true;
  });
  mock('injectScript', (url, onSuccess) => {
    injectedUrl = url;
    onSuccess();
  });


___NOTES___

Maintained by Concedo (https://www.concedo.com.br). Checked by conferir.mjs in the
source repository; see README.md.
