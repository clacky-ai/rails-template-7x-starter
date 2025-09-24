(function() {
  window.App = window.App || { cable: null }
  window.App.adminSidebar = {
    saveSidebarScrollPosition() {
      const adminPage = this.page()
      if (adminPage) {
        const sidebar = adminPage.querySelector('.sidebar')
        if (sidebar) {
          const sidebarScrollTop = sidebar.scrollTop
          localStorage.setItem('admin-SidebarScrollTop', sidebarScrollTop.toString())
        }
      }
    },

    restoreSidebarScrollPosition() {
      const adminPage = this.page()
      if (adminPage) {
        const sidebar = adminPage.querySelector('.sidebar')
        const sidebarScrollTop = localStorage.getItem('admin-SidebarScrollTop')
        if (sidebar && sidebarScrollTop) {
          sidebar.scrollTop = sidebarScrollTop
        }
      }
    },

    clearSidebarScrollPosition() {
      localStorage.setItem('admin-SidebarScrollTop', '0')
    },

    page() {
      return document.querySelector('.admin-page')
    },
  }
}).call(this)

document.addEventListener('DOMContentLoaded', function() {
  const component = document.querySelector('.admin-page')
  if (component) {
    App.adminSidebar.restoreSidebarScrollPosition()
  }
})

document.addEventListener('beforeunload', function() {
  const component = document.querySelector('.admin-page')
  if (component) {
    App.adminSidebar.saveSidebarScrollPosition()
  } else {
    App.adminSidebar.clearSidebarScrollPosition()
  }
})
