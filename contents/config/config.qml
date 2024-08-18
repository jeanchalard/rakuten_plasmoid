import QtQuick 2.6
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
         name : i18n("Modules")
         icon : "configure"
         source : "ConfigModules.qml"
    }
    ConfigCategory {
         name : i18n("Updating")
         icon : "backup"
         source : "ConfigUpdates.qml"
    }
}
