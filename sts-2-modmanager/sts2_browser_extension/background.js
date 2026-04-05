// STS2 Mod Manager - Background Service Worker V3.1
// Handles download URL forwarding with CDN interception

const SERVER_URL = 'http://localhost:8765';
const ENDPOINTS = {
  download: '/api/download',
  status: '/api/status'
};

// Download intercept state
let interceptingDownload = false;
let pendingDownloadInfo = null;

// Handle messages from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('[STS2-Ext] Received message:', message.type);

  if (message.type === 'DOWNLOAD_READY') {
    handleDownloadReady(message.data)
      .then(result => sendResponse({ success: true, data: result }))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }

  if (message.type === 'DOWNLOAD_MOD') {
    handleDownloadMod(message.data)
      .then(result => sendResponse({ success: true, data: result }))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }

  if (message.type === 'CHECK_STATUS') {
    checkServerStatus()
      .then(result => sendResponse({ success: true, data: result }))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }

  if (message.type === 'START_NXM_INTERCEPT') {
    // Content script detected NXM URL, start intercepting CDN
    pendingDownloadInfo = message.data;
    interceptingDownload = true;
    console.log('[STS2-Ext] Starting NXM intercept for:', message.data);
    sendResponse({ success: true });
    return true;
  }

  return false;
});

// Listen for web requests to find CDN download URLs
if (chrome.webRequest) {
  chrome.webRequest.onBeforeRequest.addListener(
    (details) => {
      if (!interceptingDownload) return null;

      const url = details.url;
      console.log('[STS2-Ext] WebRequest intercept:', url.substring(0, 100));

      // Look for CDN or direct download URLs from nexusmods
      // Also check for supporter-files.nexus-cdn.com (actual download URLs)
      if (url.includes('files.nexusmods.com') ||
          url.includes('cdn.nexusmods.com') ||
          url.includes('supporter-files.nexus-cdn.com') ||
          (url.includes('nexusmods.com') && (url.includes('.zip') || url.includes('.7z') || url.includes('.rar')))) {
        console.log('[STS2-Ext] Intercepted CDN URL:', url);
        interceptingDownload = false;

        // Send to content script
        chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
          if (tabs[0]) {
            chrome.tabs.sendMessage(tabs[0].id, {
              type: 'CDN_URL_INTERCEPTED',
              data: { url: url, info: pendingDownloadInfo }
            }).catch(err => {
              console.log('[STS2-Ext] Failed to send to tab:', err.message);
            });
          }
        });
      }

      return null;
    },
    {
      urls: ['*://files.nexusmods.com/*', '*://cdn.nexusmods.com/*', '*://supporter-files.nexus-cdn.com/*', '*://*.nexusmods.com/download*']
    },
    ['blocking']
  );
}

async function handleDownloadReady(data) {
  const { downloadUrl, modName, modId, key, expires, userId, fileId } = data;

  console.log('[STS2-Ext] Sending download URL to manager:', downloadUrl);
  console.log('[STS2-Ext] Additional params - key:', key ? key.substring(0, 10) + '...' : '', ', expires:', expires, ', user_id:', userId, ', file_id:', fileId);

  const url = SERVER_URL + ENDPOINTS.download;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        mod_id: modId,
        mod_name: modName,
        download_url: downloadUrl,
        key: key || '',
        expires: expires || 0,
        user_id: userId || 0,
        file_id: fileId || 0
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Server error: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    console.log('[STS2-Ext] Download request sent:', result);
    return result;
  } catch (error) {
    console.error('[STS2-Ext] Download failed:', error);
    throw error;
  }
}

async function handleDownloadMod(modData) {
  const url = SERVER_URL + ENDPOINTS.download;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        mod_id: modData.modId,
        mod_name: modData.modName,
        mod_page_url: modData.modPageUrl,
        version: modData.version || '',
        download_url: modData.downloadUrl || ''
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Server error: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    console.log('[STS2-Ext] Download request sent:', result);
    return result;
  } catch (error) {
    console.error('[STS2-Ext] Download failed:', error);
    throw error;
  }
}

async function checkServerStatus() {
  const url = SERVER_URL + ENDPOINTS.status;

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Server not available: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    return { running: false, error: error.message };
  }
}

// Handle extension icon click
chrome.action.onClicked.addListener(async (tab) => {
  console.log('[STS2-Ext] Extension icon clicked');
});