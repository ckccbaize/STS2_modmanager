// STS2 Mod Manager - Popup Script

const DEFAULT_PORT = 8765;
let serverPort = DEFAULT_PORT;

// Translation strings
const translations = {
  en: {
    headerTitle: 'STS2 Mod Manager',
    headerSubtitle: 'Browser Extension',
    tabMain: 'Main',
    tabSettings: 'Settings',
    managerStatus: 'Manager Status',
    checking: 'Checking...',
    online: 'Online',
    offline: 'Offline',
    activeDownloads: 'Active Downloads',
    installedMods: 'Installed Mods',
    howToUse: 'How to use:',
    howToUseSteps: '1. Open Nexus Mods and find a mod for Slay the Spire 2\n2. Click the "Download to STS2 Manager" button\n3. The mod will be sent directly to the manager!',
    checkStatusBtn: 'Check Status',
    openManagerBtn: 'Open STS2 Mod Manager',
    version: 'v3.0.6 | STS2-ModManager | No Premium Required',
    languageLabel: 'Language / 语言',
    languageHint: 'Select the display language',
    portLabel: 'Port',
    portHint: 'Local server port (default: 8765)',
    saveSettingsBtn: 'Save Settings',
    resetSettingsBtn: 'Reset to Defaults',
    settingsSaved: 'Settings saved successfully!',
    managerNotRunning: 'Manager not running. Please open STS2 Mod Manager first.'
  },
  zh: {
    headerTitle: 'STS2 模组管理器',
    headerSubtitle: '浏览器插件',
    tabMain: '主页',
    tabSettings: '设置',
    managerStatus: '管理器状态',
    checking: '检查中...',
    online: '在线',
    offline: '离线',
    activeDownloads: '正在下载',
    installedMods: '已安装模组',
    howToUse: '使用方法：',
    howToUseSteps: '1. 打开 Nexus Mods，找到杀戮尖塔2的模组\n2. 点击"下载到 STS2 管理器"按钮\n3. 模组将直接发送到管理器！',
    checkStatusBtn: '检查状态',
    openManagerBtn: '打开 STS2 管理器',
    version: 'v3.0.6 | STS2-ModManager | made_by_baize',
    languageLabel: '语言 / Language',
    languageHint: '选择显示语言',
    portLabel: '端口',
    portHint: '本地服务器端口（默认：8765）',
    saveSettingsBtn: '保存设置',
    resetSettingsBtn: '恢复默认',
    settingsSaved: '设置已保存！',
    managerNotRunning: '管理器未运行。请先打开 STS2 模组管理器。'
  }
};

let currentLang = 'en';

function t(key) {
  return translations[currentLang][key] || key;
}

function getServerUrl() {
  return `http://localhost:${serverPort}`;
}

async function loadSettings() {
	return new Promise((resolve) => {
		chrome.storage.local.get(['language', 'port'], (result) => {
			currentLang = result.language || 'en';
			serverPort = result.port || DEFAULT_PORT;
			resolve();
		});
	});
}

function updateLanguage() {
  // Update header
  document.querySelector('.header-left h1').textContent = t('headerTitle');
  document.querySelector('.header-left p').textContent = t('headerSubtitle');

  // Update tabs
  document.getElementById('tab-main').textContent = t('tabMain');
  document.getElementById('tab-settings').textContent = t('tabSettings');

  // Update status card
  const statusRow = document.querySelector('.status-card .status-row:first-child .status-label');
  if (statusRow) statusRow.textContent = t('managerStatus');

  document.querySelectorAll('.status-card .status-row')[1].querySelector('.status-label').textContent = t('activeDownloads');
  document.querySelectorAll('.status-card .status-row')[2].querySelector('.status-label').textContent = t('installedMods');

  // Update info section
  const infoSection = document.querySelector('.info-section');
  infoSection.innerHTML = `<p>💡 <strong>${t('howToUse')}</strong><br>${t('howToUseSteps').replace('\n', '<br>')}</p>`;

  // Update buttons
  document.getElementById('refresh-btn').textContent = t('checkStatusBtn');
  document.getElementById('open-manager-btn').textContent = t('openManagerBtn');

  // Update footer
  document.querySelector('.footer').textContent = t('version');

  // Update settings tab
  document.getElementById('label-language').textContent = t('languageLabel');
  document.getElementById('hint-language').textContent = t('languageHint');
  document.getElementById('label-port').textContent = t('portLabel');
  document.getElementById('hint-port').textContent = t('portHint');
  document.getElementById('save-settings-btn').textContent = t('saveSettingsBtn');
  document.getElementById('reset-settings-btn').textContent = t('resetSettingsBtn');
}

function initTabs() {
  const tabMain = document.getElementById('tab-main');
  const tabSettings = document.getElementById('tab-settings');
  const contentMain = document.getElementById('content-main');
  const contentSettings = document.getElementById('content-settings');

  tabMain.addEventListener('click', () => {
    tabMain.classList.add('active');
    tabSettings.classList.remove('active');
    contentMain.classList.add('active');
    contentSettings.classList.remove('active');
  });

  tabSettings.addEventListener('click', () => {
    tabSettings.classList.add('active');
    tabMain.classList.remove('active');
    contentSettings.classList.add('active');
    contentMain.classList.remove('active');
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  await loadSettings();
  updateLanguage();
  initTabs();

  // Initialize form values
  document.getElementById('language-select').value = currentLang;
  document.getElementById('port-input').value = serverPort;

  const statusIndicator = document.querySelector('#server-status');
  const activeDownloadsEl = document.getElementById('active-downloads');
  const installedModsEl = document.getElementById('installed-mods');
  const errorSection = document.getElementById('error-section');
  const errorMessage = document.getElementById('error-message');
  const refreshBtn = document.getElementById('refresh-btn');
  const openManagerBtn = document.getElementById('open-manager-btn');
  const successMsg = document.getElementById('success-msg');

  async function checkStatus() {
    refreshBtn.disabled = true;
    refreshBtn.innerHTML = '<span class="loading"></span>' + (currentLang === 'zh' ? '检查中...' : 'Checking...');

    try {
      const response = await fetch(`${getServerUrl()}/api/status`);

      if (!response.ok) {
        throw new Error(`Server returned ${response.status}`);
      }

      const data = await response.json();

      statusIndicator.innerHTML = `
        <span class="status-indicator online"></span>
        <span>${t('online')}</span>
      `;

      activeDownloadsEl.textContent = data.active_downloads || 0;
      installedModsEl.textContent = data.installed_mods || 0;

      errorSection.style.display = 'none';

    } catch (error) {
      console.error('[STS2-Ext] Status check failed:', error);

      statusIndicator.innerHTML = `
        <span class="status-indicator offline"></span>
        <span>${t('offline')}</span>
      `;
      activeDownloadsEl.textContent = '-';
      installedModsEl.textContent = '-';

      errorSection.style.display = 'block';
      errorMessage.textContent = t('managerNotRunning');
    }

    refreshBtn.disabled = false;
    refreshBtn.textContent = t('checkStatusBtn');
  }

  // Save settings
  document.getElementById('save-settings-btn').addEventListener('click', () => {
    const newLang = document.getElementById('language-select').value;
    const newPort = parseInt(document.getElementById('port-input').value, 10);

    chrome.storage.local.set({
      language: newLang,
      port: newPort
    }, () => {
      currentLang = newLang;
      serverPort = newPort;
      updateLanguage();

      successMsg.classList.add('show');
      setTimeout(() => {
        successMsg.classList.remove('show');
      }, 2000);
    });
  });

  // Reset settings
  document.getElementById('reset-settings-btn').addEventListener('click', () => {
    chrome.storage.local.set({
      language: 'en',
      port: DEFAULT_PORT
    }, () => {
      currentLang = 'en';
      serverPort = DEFAULT_PORT;
      document.getElementById('language-select').value = 'en';
      document.getElementById('port-input').value = DEFAULT_PORT;
      updateLanguage();

      successMsg.classList.add('show');
      setTimeout(() => {
        successMsg.classList.remove('show');
      }, 2000);
    });
  });

  refreshBtn.addEventListener('click', checkStatus);

  openManagerBtn.addEventListener('click', () => {
    alert(currentLang === 'zh' ? '请从桌面或开始菜单打开 STS2 模组管理器。' : 'Please open STS2 Mod Manager from your desktop or start menu.');
  });

  checkStatus();
});