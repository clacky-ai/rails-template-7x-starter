// Simple Clipboard Utility
// Copy to clipboard with fallback support for iframe and older browsers

function copyToClipboard(text: string): Promise<boolean> {
  return new Promise<boolean>((resolve, reject) => {
    // Try modern Clipboard API first
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text)
        .then(() => resolve(true))
        .catch(() => {
          if (fallbackCopy(text)) {
            resolve(true);
          } else {
            reject(new Error('Copy failed'));
          }
        });
    } else {
      if (fallbackCopy(text)) {
        resolve(true);
      } else {
        reject(new Error('Copy failed'));
      }
    }
  });
}

function fallbackCopy(text: string): boolean {
  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.style.position = 'fixed';
  textArea.style.opacity = '0';
  document.body.appendChild(textArea);
  textArea.select();

  try {
    const success = document.execCommand('copy');
    document.body.removeChild(textArea);
    return success;
  } catch (error) {
    document.body.removeChild(textArea);
    return false;
  }
}

// Export globally
window.copyToClipboard = copyToClipboard;
