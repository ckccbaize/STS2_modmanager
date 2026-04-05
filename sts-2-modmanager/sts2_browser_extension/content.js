// STS2 Mod Manager - Content Script V3.1
// Uses nmm=1 parameter to bypass countdown page
// Detects NXM URL and intercepts CDN redirect through background.js

(function() {
  'use strict';

  console.log('[STS2-Ext] Content script loaded on Nexus Mods (V3.1)');

  // Detect current page type
  function getPageType() {
    const url = window.location.href;
    console.log('[STS2-Ext] Current URL:', url);

    // Check if this is a download page with nmm=1 (bypassed countdown)
    // 使用 nmm=1 来跳过倒计时，直接显示下载按钮
    if (url.includes('file_id=') && url.includes('nmm=1')) {
      // 带 nmm=1 的下载页面，提取 NXM 参数
      return 'download-nmm';
    }

    // Regular files page
    if (url.includes('tab=files') && url.match(/\/mods\/\d+/)) {
      return 'files';
    }

    // Regular download page (without nmm=1) - 这里会有 "click here" 链接
    // 但我们现在用 nmm=1 了，所以这个分支基本不会走到
    if (url.includes('file_id=') && !url.includes('nmm=1')) {
      return 'download-page';
    }

    // Also check if it's a mod page with /mods/XX pattern
    if (url.match(/\/mods\/\d+/) && !url.includes('tab=')) {
      if (document.querySelector('dd[data-id]') || document.querySelector('.file-list')) {
        return 'files';
      }
    }

    return 'unknown';
  }

  const pageType = getPageType();
  console.log('[STS2-Ext] Page type:', pageType);

  // For any page with /mods/XX pattern, also check for file items
  if (pageType === 'unknown' && window.location.href.match(/\/mods\/\d+/)) {
    const hasFiles = document.querySelector('dd[data-id]') !== null;
    console.log('[STS2-Ext] Unknown page but has files:', hasFiles);
    if (hasFiles) {
      initFilesPage();
      return;
    } else {
      fallbackScanDownloadLinks();
      return;
    }
  }

  if (pageType === 'redirecting') {
    return;  // 正在重定向
  } else if (pageType === 'download-nmm') {
    handleNmmDownloadPage();  // nmm=1 页面，提取 NXM URL
  } else if (pageType === 'download-page') {
    handleDirectDownloadPage();  // 普通下载页面，找 "click here"
  } else if (pageType === 'files') {
    initFilesPage();
  } else if (pageType === 'download-legacy') {
    redirectToNmm1();
  } else {
    initModPage();
  }

  // ============================================
  // Listen for CDN URL from background.js
  // ============================================
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'CDN_URL_INTERCEPTED') {
      console.log('[STS2-Ext] Received CDN URL from background:', message.data.url);
      sendDownloadUrl(message.data.url);
      return true;
    }
    return false;
  });

  // ============================================
  // REDIRECT: Legacy download page → nmm=1
  // ============================================
  function redirectToNmm1() {
    console.log('[STS2-Ext] Redirecting to nmm=1 version...');
    const url = new URL(window.location.href);
    url.searchParams.set('nmm', '1');
    window.location.href = url.toString();
  }

  // ============================================
  // FILES PAGE: Inject buttons with nmm=1 logic
  // ============================================
  function initFilesPage() {
    console.log('[STS2-Ext] Initializing Files page (V3.1)');

    function tryInject() {
      const fileItems = document.querySelectorAll('dd.clearfix[data-id]');
      console.log('[STS2-Ext] Checking for file items, found:', fileItems.length);

      if (fileItems.length === 0) {
        setTimeout(tryInject, 1000);
        return;
      }

      injectButtonsOnFilesPage();
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', tryInject);
    } else {
      tryInject();

      const observer = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
          for (const node of mutation.addedNodes) {
            if (node.nodeType === Node.ELEMENT_NODE) {
              injectButtonsOnFilesPage();
            }
          }
        }
      });

      observer.observe(document.body, { childList: true, subtree: true });
    }
  }

  function injectButtonsOnFilesPage() {
    let fileItems = document.querySelectorAll('dd.clearfix[data-id]');
    if (fileItems.length === 0) {
      fileItems = document.querySelectorAll('dd[data-id]');
    }
    if (fileItems.length === 0) {
      fileItems = document.querySelectorAll('.file-item[data-id]');
    }

    console.log('[STS2-Ext] Found', fileItems.length, 'file items');

    fileItems.forEach(item => {
      if (item.querySelector('.sts2-download-btn')) {
        return;
      }

      let downloadList = item.querySelector('ul.accordion-downloads, ul.downloads, ul.actions, .download-links');
      if (!downloadList) {
        downloadList = item.querySelector('ul');
      }

      if (!downloadList) {
        console.log('[STS2-Ext] No download list found for item');
        return;
      }

      if (downloadList.querySelector('.sts2-download-btn')) {
        return;
      }

      console.log('[STS2-Ext] Adding button to download list');
      addSts2ButtonToFileItem(item, downloadList);
    });
  }

  function addSts2ButtonToFileItem(fileItem, downloadList) {
    const fileId = fileItem.getAttribute('data-id');

    const modIdMatch = window.location.href.match(/mods\/(\d+)/);
    const modId = modIdMatch ? modIdMatch[1] : 0;

    let modName = 'Unknown Mod';
    const titleEl = document.querySelector('.mod-intro-header h1, h1[class*="title"], .header-title h1');
    if (titleEl) {
      modName = titleEl.textContent.trim();
    }

    // Find Manual button and get its href
    const downloadLinks = downloadList.querySelectorAll('a');
    let manualLink = null;
    for (const link of downloadLinks) {
      const text = link.textContent.trim().toLowerCase();
      if (text.includes('manual')) {
        manualLink = link;
        break;
      }
    }

    let downloadUrl = '';

    if (manualLink) {
      const href = manualLink.getAttribute('href') || '';
      if (href) {
        // 使用 nmm=1 跳过倒计时，直接获取 NXM 链接
        const urlObj = new URL(href, window.location.origin);
        urlObj.searchParams.set('nmm', '1');  // 添加 nmm=1 参数
        downloadUrl = urlObj.toString();
      }
    } else {
      downloadUrl = `https://www.nexusmods.com/slaythespire2/mods/${modId}?tab=files&file_id=${fileId}&nmm=1`;
    }

    console.log('[STS2-Ext] Download URL with nmm=1:', downloadUrl);

    const btn = document.createElement('li');
    btn.className = 'sts2-download-btn-wrapper';

    const link = document.createElement('a');
    link.className = 'sts2-download-btn btn inline-flex';
    link.href = downloadUrl;

    const svgIcon = `<svg class="icon"><use xlink:href="/assets/images/icons/icons.svg#icon-download"></use></svg>`;
    link.innerHTML = `
      ${svgIcon}
      <span class="flex-label">Mod manager download</span>
    `;

    link.style.cssText = `
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      color: white;
      border: none;
      border-radius: 4px;
      padding: 6px 12px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    `;

    link.addEventListener('mouseenter', () => {
      link.style.transform = 'translateY(-1px)';
      link.style.boxShadow = '0 2px 8px rgba(99, 102, 241, 0.4)';
    });

    link.addEventListener('mouseleave', () => {
      link.style.transform = 'translateY(0)';
      link.style.boxShadow = 'none';
    });

    btn.appendChild(link);
    downloadList.appendChild(btn);

    console.log('[STS2-Ext] Added STS2 button for file_id:', fileId, 'with nmm=1');
  }

  // ============================================
  // NMM DOWNLOAD PAGE (nmm=1): Extract NXM URL
  // ============================================
  function handleNmmDownloadPage() {
    console.log('[STS2-Ext] ===== HANDLING NMM DOWNLOAD PAGE (nmm=1) =====');
    console.log('[STS2-Ext] URL:', window.location.href);

    showStatusMessage('Getting download link...');

    // Get mod info from URL
    const modIdMatch = window.location.href.match(/mods\/(\d+)/);
    const fileIdMatch = window.location.href.match(/file_id=(\d+)/);
    const modId = modIdMatch ? modIdMatch[1] : 0;
    const fileId = fileIdMatch ? fileIdMatch[1] : 0;

    let modName = 'Unknown Mod';
    const titleEl = document.querySelector('h1, .mod-title, .mod-intro-header h1');
    if (titleEl) {
      modName = titleEl.textContent.trim();
    }

    // Wait for NXM link to appear
    waitForNxmLink(modId, fileId, modName);
  }

  function waitForNxmLink(modId, fileId, modName) {
    let pollCount = 0;
    const maxPolls = 30;
    const pollInterval = 500;

    const checkAndFetch = () => {
      pollCount++;
      console.log('[STS2-Ext] Checking for NXM link, attempt:', pollCount);

      // Look for NXM URL link
      const nxmLinks = document.querySelectorAll('a[href^="nxm://"]');
      if (nxmLinks.length > 0) {
        const nxmUrl = nxmLinks[0].href;
        console.log('[STS2-Ext] Found NXM URL:', nxmUrl);
        sendNxmDownloadUrl(nxmUrl, modId, fileId, modName);
        return;
      }

      // Also check for any link with key parameter
      const allLinks = document.querySelectorAll('a');
      for (const link of allLinks) {
        const href = link.href || '';
        const text = link.textContent.trim().toLowerCase();

        if (href.startsWith('nxm://')) {
          console.log('[STS2-Ext] Found NXM link:', href);
          sendNxmDownloadUrl(href, modId, fileId, modName);
          return;
        }
      }

      if (pollCount < maxPolls) {
        setTimeout(checkAndFetch, pollInterval);
      } else {
        console.log('[STS2-Ext] Max polls reached, no NXM link found');
        showStatusMessage('Could not get download link', 'error');
      }
    };

    // Start checking after a short delay
    setTimeout(checkAndFetch, 1000);
  }

  // ============================================
  // DIRECT DOWNLOAD PAGE (no nmm=1): Wait for countdown, find "click here" link
  // ============================================
  function handleDirectDownloadPage() {
    console.log('[STS2-Ext] ===== HANDLING DIRECT DOWNLOAD PAGE =====');
    console.log('[STS2-Ext] URL:', window.location.href);

    showStatusMessage('Waiting for download page...');

    // Get mod info from URL
    const modIdMatch = window.location.href.match(/mods\/(\d+)/);
    const fileIdMatch = window.location.href.match(/file_id=(\d+)/);
    const modId = modIdMatch ? modIdMatch[1] : 0;
    const fileId = fileIdMatch ? fileIdMatch[1] : 0;

    let modName = 'Unknown Mod';
    const titleEl = document.querySelector('h1, .mod-title, .mod-intro-header h1');
    if (titleEl) {
      modName = titleEl.textContent.trim();
    }

    // Wait for countdown to complete, then find "click here" link
    waitForDownloadLink(modId, fileId, modName);
  }

  function waitForDownloadLink(modId, fileId, modName) {
    let pollCount = 0;
    const maxPolls = 30;  // Wait up to 15 seconds
    const pollInterval = 500;

    const checkAndFetch = async () => {
      pollCount++;
      console.log('[STS2-Ext] Checking for download link, attempt:', pollCount);

      // Try to find "click here" link
      const links = document.querySelectorAll('a');
      let clickHereLink = null;

      for (const link of links) {
        const text = link.textContent.trim().toLowerCase();
        // Look for "click here" text
        if (text.includes('click here') || (text.includes('click') && text.includes('here'))) {
          clickHereLink = link;
          console.log('[STS2-Ext] Found "click here" link:', link.href);
          break;
        }
      }

      if (clickHereLink && clickHereLink.href) {
        const actualUrl = clickHereLink.href;
        console.log('[STS2-Ext] Click here href:', actualUrl);

        // Check if it's a direct download URL
        if (actualUrl.includes('nexus-cdn.com') || actualUrl.includes('files.nexusmods.com') ||
            actualUrl.endsWith('.zip') || actualUrl.endsWith('.7z') || actualUrl.endsWith('.rar')) {
          console.log('[STS2-Ext] Found direct download URL:', actualUrl);
          sendDownloadUrl(actualUrl, modId, modName);
          return;
        }
      }

      // Check for any link with actual download parameters
      for (const link of links) {
        const href = link.href || '';
        // Look for links with md5, expires, user_id parameters (real download URLs)
        if (href.includes('md5=') || (href.includes('expires=') && href.includes('user_id='))) {
          console.log('[STS2-Ext] Found download link with params:', href.substring(0, 100));
          if (href.includes('nexus-cdn.com') || href.includes('.zip') || href.includes('.7z')) {
            sendDownloadUrl(href, modId, modName);
            return;
          }
        }
      }

      // Check for "Your download has started" message
      const downloadStarted = document.body.textContent.includes('Your download has started');
      if (downloadStarted) {
        console.log('[STS2-Ext] Download started message found');
      }

      if (pollCount < maxPolls) {
        setTimeout(checkAndFetch, pollInterval);
      } else {
        console.log('[STS2-Ext] Max polls reached, trying fallback...');
        showStatusMessage('Could not find download link, trying API...', 'error');
        // Fallback: just send the file_id and let the manager handle it
        sendDownloadUrl('nxm://slaythespire2/mods/' + modId + '/files/' + fileId, modId, modName);
      }
    };

    // Start checking after a short delay to let page load
    setTimeout(checkAndFetch, 1000);
  }

  function findClickHereLink(modId, fileId, modName) {
    // Look for "click here" link that contains the actual download URL
    const links = document.querySelectorAll('a');
    let clickHereLink = null;

    for (const link of links) {
      const text = link.textContent.trim().toLowerCase();
      // Look for "click here" or similar text
      if (text.includes('click here') || text.includes('click') && text.includes('here')) {
        clickHereLink = link;
        console.log('[STS2-Ext] Found "click here" link:', link.href);
        break;
      }
    }

    if (clickHereLink && clickHereLink.href) {
      const actualUrl = clickHereLink.href;
      // Check if it's a direct download URL (supporter-files.nexus-cdn.com)
      if (actualUrl.includes('nexus-cdn.com') || actualUrl.includes('files.nexusmods.com') ||
          actualUrl.endsWith('.zip') || actualUrl.endsWith('.7z')) {
        console.log('[STS2-Ext] Found direct download URL:', actualUrl);
        sendDownloadUrl(actualUrl, modId, modName);
        return;
      }
    }

    // Method 2: Fallback to NXM URL detection
    console.log('[STS2-Ext] No "click here" link found, trying NXM detection');
    findAndSendNxmUrl(modId, fileId, modName);
  }

  function findAndSendNxmUrl(modId, fileId, modName) {
    // Look for NXM URL - it's typically in a link that gets clicked
    const nxmLinks = document.querySelectorAll('a[href^="nxm://"]');
    console.log('[STS2-Ext] Found NXM links:', nxmLinks.length);

    if (nxmLinks.length > 0) {
      // Found NXM URL - send the full URL to manager
      const nxmUrl = nxmLinks[0].href;
      console.log('[STS2-Ext] NXM URL:', nxmUrl);

      // Send NXM URL directly to manager - it contains the download key info
      sendNxmDownloadUrl(nxmUrl, modId, fileId, modName);
      return;
    }

    // Also check for any link that might have the download info
    // Look for links with 'download' text or specific classes
    const allLinks = document.querySelectorAll('a');
    for (const link of allLinks) {
      const href = link.href;
      const text = link.textContent.trim().toLowerCase();

      // Check if this might be the actual download button
      if (href && (text.includes('download') || text.includes('slow'))) {
        console.log('[STS2-Ext] Found download link:', href);

        // If it's an nxm URL, send it
        if (href.startsWith('nxm://')) {
          sendNxmDownloadUrl(href, modId, fileId, modName);
          return;
        }
      }
    }

    // Fallback: try to find any link with key parameter (direct download link)
    const keyLinks = document.querySelectorAll('a[href*="key="]');
    for (const link of keyLinks) {
      const href = link.href;
      console.log('[STS2-Ext] Found key link:', href.substring(0, 100));

      // Check if it's a direct download URL
      if (href.includes('files.nexusmods.com') || href.includes('cdn.nexusmods.com') ||
          href.includes('download.php')) {
        sendDownloadUrl(href, modId, modName);
        return;
      }
    }

    // Poll for NXM URL
    let pollCount = 0;
    const maxPolls = 20;

    const pollInterval = setInterval(() => {
      pollCount++;

      const nxmLinks = document.querySelectorAll('a[href^="nxm://"]');
      if (nxmLinks.length > 0) {
        clearInterval(pollInterval);
        const nxmUrl = nxmLinks[0].href;
        console.log('[STS2-Ext] Found NXM URL in poll:', nxmUrl);
        sendNxmDownloadUrl(nxmUrl, modId, fileId, modName);
        return;
      }

      if (pollCount >= maxPolls) {
        clearInterval(pollInterval);
        showStatusMessage('Could not get download link', 'error');
      }
    }, 500);
  }

  async function sendNxmDownloadUrl(nxmUrl, modId, fileId, modName) {
    console.log('[STS2-Ext] sendNxmDownloadUrl called - nxmUrl:', nxmUrl);
    console.log('[STS2-Ext] sendNxmDownloadUrl called - modId:', modId, ', fileId:', fileId, ', modName:', modName);
    console.log('[STS2-Ext] Sending NXM URL:', nxmUrl);

    // 从 NXM URL 提取 key, expires, user_id 参数
    let key = '';
    let expires = 0;
    let userId = 0;

    try {
      const urlObj = new URL(nxmUrl);
      key = urlObj.searchParams.get('key') || '';
      expires = parseInt(urlObj.searchParams.get('expires') || '0');
      userId = parseInt(urlObj.searchParams.get('user_id') || '0');

      // 从 NXM URL 路径提取 file_id（格式: nxm://slaythespire2/mods/23/files/1028）
      const pathMatch = nxmUrl.match(/\/files\/(\d+)/);
      if (pathMatch) {
        console.log('[STS2-Ext] Extracted file_id from NXM URL path:', pathMatch[1]);
        fileId = parseInt(pathMatch[1]);
      }

      console.log('[STS2-Ext] Extracted params - modId:', modId, ', fileId:', fileId, ', key:', key ? key.substring(0, 10) + '...' : '', ', expires:', expires, ', user_id:', userId);
    } catch (e) {
      console.log('[STS2-Ext] Failed to parse NXM URL params:', e);
    }

    showStatusMessage('Sending to Mod Manager...');

    console.log('[STS2-Ext] Sending to background - fileId:', fileId);

    try {
      // 发送 NXM URL 以及提取的参数 - 让 Mod Manager 使用 Nexus API 获取直链
      const response = await chrome.runtime.sendMessage({
        type: 'DOWNLOAD_READY',
        data: {
          downloadUrl: nxmUrl,
          modId: modId,
          modName: modName,
          key: key,
          expires: expires,
          userId: userId,
          fileId: fileId
        }
      });

      if (response.success) {
        console.log('[STS2-Ext] NXM URL sent successfully');
        showStatusMessage('✓ Sent to Mod Manager!', 'success');
      } else {
        throw new Error(response.error || 'Failed to send NXM URL');
      }
    } catch (error) {
      console.error('[STS2-Ext] Failed to send NXM URL:', error);
      showStatusMessage('✕ Failed to send to Mod Manager', 'error');
    }
  }

  // ============================================
  // FALLBACK: Scan page for download links
  // ============================================
  function fallbackScanDownloadLinks() {
    console.log('[STS2-Ext] Running fallback scan for download links');

    const downloadLinks = document.querySelectorAll('a[href*="file_id="]');
    console.log('[STS2-Ext] Found download links:', downloadLinks.length);

    if (downloadLinks.length === 0) {
      setTimeout(fallbackScanDownloadLinks, 2000);
      return;
    }

    const fileIds = new Set();
    downloadLinks.forEach(link => {
      const match = link.href.match(/file_id=(\d+)/);
      if (match) {
        fileIds.add(match[1]);
      }
    });

    console.log('[STS2-Ext] Found file IDs:', Array.from(fileIds));

    fileIds.forEach(fileId => {
      const linksWithFileId = document.querySelectorAll(`a[href*="file_id=${fileId}"]`);

      let downloadList = null;
      for (const link of linksWithFileId) {
        const ul = link.closest('ul');
        if (ul) {
          if (!ul.querySelector('.sts2-download-btn')) {
            downloadList = ul;
            break;
          }
        }
      }

      if (downloadList) {
        const fileItem = downloadList.closest('dd') || downloadList.parentElement;
        addSts2ButtonToFileItem(fileItem, downloadList);
      }
    });

    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            const links = node.querySelectorAll && node.querySelectorAll('a[href*="file_id="]');
            if (links && links.length > 0) {
              fallbackScanDownloadLinks();
            }
          }
        }
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });
  }

  // ============================================
  // Send download URL to manager
  // ============================================
  async function sendDownloadUrl(downloadUrl, forcedModId = null, forcedModName = null) {
    let modId = forcedModId;
    let modName = forcedModName;

    // If not provided, extract from page
    if (modId === null) {
      const modIdMatch = window.location.href.match(/mods\/(\d+)/);
      modId = modIdMatch ? modIdMatch[1] : 0;
    }

    if (modName === null) {
      const titleEl = document.querySelector('h1, .mod-title');
      modName = titleEl ? titleEl.textContent.trim() : 'Unknown Mod';
    }

    showStatusMessage('Sending to Mod Manager...');

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'DOWNLOAD_READY',
        data: {
          downloadUrl: downloadUrl,
          modId: modId,
          modName: modName
        }
      });

      if (response.success) {
        console.log('[STS2-Ext] Download URL sent successfully');
        showStatusMessage('✓ Sent to Mod Manager!', 'success');
      } else {
        throw new Error(response.error || 'Failed to send download URL');
      }
    } catch (error) {
      console.error('[STS2-Ext] Failed to send download URL:', error);
      showStatusMessage('✕ Failed to send to Mod Manager', 'error');
    }
  }

  function showStatusMessage(message, type = 'info') {
    const existing = document.getElementById('sts2-status');
    if (existing) existing.remove();

    const statusEl = document.createElement('div');
    statusEl.id = 'sts2-status';

    const bgColor = type === 'success' ? '#22c55e' : type === 'error' ? '#ef4444' : '#6366f1';
    const icon = type === 'success' ? '✓' : type === 'error' ? '✕' : '⏳';

    statusEl.innerHTML = `
      <div style="
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 16px 24px;
        background: ${bgColor};
        color: white;
        border-radius: 8px;
        font-family: system-ui, -apple-system, sans-serif;
        font-size: 14px;
        z-index: 99999;
        box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        gap: 12px;
        animation: slideIn 0.3s ease;
      ">
        <span style="font-size: 18px;">${icon}</span>
        <span>${message}</span>
      </div>
      <style>
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
      </style>
    `;

    document.body.appendChild(statusEl);

    if (type !== 'success') {
      setTimeout(() => {
        if (statusEl.parentNode) {
          statusEl.remove();
        }
      }, 10000);
    }
  }

  // ============================================
  // FALLBACK: Original mod page behavior
  // ============================================
  function initModPage() {
    console.log('[STS2-Ext] Initializing on mod description page');

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => injectDownloadButton());
    } else {
      injectDownloadButton();
    }
  }

  function injectDownloadButton() {
    const modHeader = document.querySelector('.mod-header, .mod-title, h1.mod-name, [class*="header"]');
    if (!modHeader) {
      console.log('[STS2-Ext] Could not find mod header');
      setTimeout(injectDownloadButton, 2000);
      return;
    }

    if (document.getElementById('sts2-download-btn')) {
      return;
    }

    const btn = document.createElement('button');
    btn.id = 'sts2-download-btn';
    btn.className = 'sts2-download-btn';
    btn.innerHTML = `
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
        <polyline points="7 10 12 15 17 10"/>
        <line x1="12" y1="15" x2="12" y2="3"/>
      </svg>
      Download to STS2 Manager
    `;

    btn.style.cssText = `
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 20px;
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
      box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
      margin-left: 12px;
      vertical-align: middle;
    `;

    btn.onmouseover = () => {
      btn.style.transform = 'translateY(-2px)';
      btn.style.boxShadow = '0 6px 16px rgba(99, 102, 241, 0.4)';
    };

    btn.onmouseout = () => {
      btn.style.transform = 'translateY(0)';
      btn.style.boxShadow = '0 4px 12px rgba(99, 102, 241, 0.3)';
    };

    btn.onclick = () => downloadMod(btn);

    const downloadSection = document.querySelector('.mod-description, .file-actions, [class*="download"], .header-actions');
    if (downloadSection) {
      downloadSection.parentNode.insertBefore(btn, downloadSection);
    } else if (modHeader) {
      modHeader.parentNode.insertBefore(btn, modHeader.nextSibling);
    }

    console.log('[STS2-Ext] Download button injected on mod page');
  }

  async function downloadMod(btn) {
    const originalText = btn.innerHTML;
    btn.innerHTML = '⏳ Sending...';
    btn.disabled = true;

    try {
      const modData = getModData();
      console.log('[STS2-Ext] Sending download request:', modData);

      const response = await chrome.runtime.sendMessage({
        type: 'DOWNLOAD_MOD',
        data: modData
      });

      if (response.success) {
        btn.innerHTML = '✓ Sent to Manager!';
        btn.style.background = '#22c55e';
        setTimeout(() => {
          btn.innerHTML = originalText;
          btn.style.background = '';
          btn.disabled = false;
        }, 3000);
      } else {
        throw new Error(response.error || 'Unknown error');
      }
    } catch (error) {
      console.error('[STS2-Ext] Download error:', error);
      btn.innerHTML = '✕ Failed';
      btn.style.background = '#ef4444';
      setTimeout(() => {
        btn.innerHTML = originalText;
        btn.style.background = '';
        btn.disabled = false;
      }, 3000);
    }
  }

  function getModData() {
    const modIdMatch = window.location.href.match(/mods\/(\d+)/);
    const modId = modIdMatch ? parseInt(modIdMatch[1]) : 0;

    let modName = '';
    const nameEl = document.querySelector('h1.mod-name, .mod-header h1, h1[class*="title"]');
    if (nameEl) modName = nameEl.textContent.trim();

    let version = '';
    const versionEl = document.querySelector('[class*="version"], .mod-version, .file-version');
    if (versionEl) version = versionEl.textContent.trim().replace('Version:', '').trim();

    return {
      modId,
      modName: modName || 'Unknown Mod',
      modPageUrl: window.location.href,
      version: version || '',
      downloadUrl: ''
    };
  }

})();