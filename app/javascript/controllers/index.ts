import { Application } from "@hotwired/stimulus"

import ThemeController from "./theme_controller"
import DropdownController from "./dropdown_controller"
import SdkIntegrationController from "./sdk_integration_controller"
import ClipboardController from "./clipboard_controller"

const application = Application.start()

application.register("theme", ThemeController)
application.register("dropdown", DropdownController)
application.register("sdk-integration", SdkIntegrationController)
application.register("clipboard", ClipboardController)

window.Stimulus = application
