import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.4 as Kirigami
import org.kde.plasma.plasmoid 2.0
import "util.js" as Util

Kirigami.ScrollablePage {
  Column {
    id : configList
    Layout.fillWidth : true

    function saveConfig() {
      var spec = { modules : [] }
      for (var i = 0; i < configList.children.length; ++i) {
        var s = configList.children[i].saveConfig()
        spec.modules.push(s)
      }
      Plasmoid.configuration["spec"] = Util.encodeSpec(spec)
    }

    Connections {
      target : applyAction
      function onTriggered() { configList.saveConfig() }
    }

    Component.onCompleted : {
      var spec = Util.decodeSpec(Plasmoid.configuration["spec"])
      spec.modules.forEach((module) => {
        var q = Qt.createComponent("modules/" + module.module + "/Config.qml")
        if (q.errorString()) {
          console.log("Error loading config for " + module + " : " + q.errorString)
        } else {
          q = q.createObject(configList)
          q.applyConfig(module)
        }
      })
    }
  }
}
