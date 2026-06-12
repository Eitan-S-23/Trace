(() => {
  'use strict';

  const PAGE_URL = 'https://eitan-s-23.github.io/Trace/';
  const APP_SCHEME_URL = 'trace://open';
  const APP_PACKAGE_NAME = 'com.wen.gaia.gaia';
  const ANDROID_APK_URL =
    'https://github.com/Eitan-S-23/Trace/releases/latest/download/ble-monitor-android.apk';
  const WINDOWS_DOWNLOAD_URL =
    'https://github.com/Eitan-S-23/Trace/releases/latest/download/ble-monitor-windows.zip';

  const userAgent = navigator.userAgent || '';
  const params = new URLSearchParams(window.location.search);
  const isWeChat = /MicroMessenger/i.test(userAgent);
  const isAndroid = /Android/i.test(userAgent);
  const isIos =
    /iPhone|iPad|iPod/i.test(userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  const openButton = document.getElementById('openAppButton');
  const copyButton = document.getElementById('copyLinkButton');
  const status = document.getElementById('openStatus');
  const wechatGuide = document.getElementById('wechatGuide');

  function fallbackPageUrl() {
    const url = new URL(PAGE_URL);
    url.searchParams.set('fallback', '1');
    return url.toString();
  }

  function androidIntentUrl() {
    return `intent://open#Intent;scheme=trace;package=${APP_PACKAGE_NAME};S.browser_fallback_url=${encodeURIComponent(
      fallbackPageUrl(),
    )};end`;
  }

  function setMode(mode) {
    document.body.dataset.mode = mode;
  }

  function setStatus(message, tone = 'normal') {
    status.textContent = message;
    status.classList.toggle('is-warning', tone === 'warning');
  }

  function wireDownloads() {
    for (const id of ['downloadAndroid', 'downloadAndroidBottom']) {
      const link = document.getElementById(id);
      if (link) link.href = ANDROID_APK_URL;
    }

    const windowsLink = document.getElementById('downloadWindows');
    if (windowsLink) windowsLink.href = WINDOWS_DOWNLOAD_URL;
  }

  function bindOpenTracking(startedAt) {
    let appLikelyOpened = false;

    const cleanup = () => {
      document.removeEventListener('visibilitychange', onVisibilityChange);
      window.removeEventListener('pagehide', onPageHide);
    };

    const onVisibilityChange = () => {
      if (document.hidden) {
        appLikelyOpened = true;
        cleanup();
      }
    };

    const onPageHide = () => {
      appLikelyOpened = true;
      cleanup();
    };

    document.addEventListener('visibilitychange', onVisibilityChange);
    window.addEventListener('pagehide', onPageHide);

    window.setTimeout(() => {
      cleanup();
      if (!appLikelyOpened && Date.now() - startedAt < 3200) {
        setMode('fallback');
        setStatus('如果没有跳转，可能尚未安装 App，或浏览器拦截了自动唤起。', 'warning');
      }
    }, 2200);
  }

  function openApp(source) {
    if (isWeChat) {
      setMode('wechat');
      wechatGuide.hidden = false;
      setStatus('请先在微信右上角菜单中选择“在浏览器打开”。', 'warning');
      return;
    }

    setStatus(source === 'auto' ? '正在尝试打开 Trace...' : '正在请求系统打开 Trace...');
    bindOpenTracking(Date.now());

    window.location.href = isAndroid ? androidIntentUrl() : APP_SCHEME_URL;
  }

  async function copyPageLink() {
    try {
      await navigator.clipboard.writeText(PAGE_URL);
      setStatus('页面链接已复制，可以粘贴到浏览器或聊天窗口。');
    } catch (_) {
      const input = document.createElement('textarea');
      input.value = PAGE_URL;
      input.setAttribute('readonly', '');
      input.style.position = 'fixed';
      input.style.opacity = '0';
      document.body.appendChild(input);
      input.select();
      document.execCommand('copy');
      input.remove();
      setStatus('页面链接已复制，可以粘贴到浏览器或聊天窗口。');
    }
  }

  function boot() {
    wireDownloads();

    openButton.addEventListener('click', () => openApp('manual'));
    copyButton.addEventListener('click', copyPageLink);

    if (isWeChat) {
      setMode('wechat');
      wechatGuide.hidden = false;
      setStatus('微信内请先选择“在浏览器打开”，打开后会自动尝试启动 App。', 'warning');
      return;
    }

    if (params.get('fallback') === '1') {
      setMode('fallback');
      setStatus('没有检测到已安装的 Trace，可以先下载 Android APK。', 'warning');
      return;
    }

    if (!isAndroid && !isIos) {
      setMode('desktop');
      return;
    }

    window.setTimeout(() => openApp('auto'), 650);
  }

  boot();
})();
