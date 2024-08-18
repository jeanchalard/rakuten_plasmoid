import QtQuick 2.0
import QtQuick.Controls 1.3 as QQC1
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.4 as Kirigami
import "../../util.js" as Util

Kirigami.FormLayout {
  id : top
  anchors.left : parent.left
  anchors.right : parent.right

  Kirigami.Separator {
    Kirigami.FormData.label : "三菱銀行"
    Kirigami.FormData.isSection : true
  }

  TextField {
    id : tenban
    Kirigami.FormData.label : i18n("店番")
    enabled : !gokeiyakubango.enabled
    onTextChanged : applyButton.enabled = true
  }
  TextField {
    id : kouzabango
    Kirigami.FormData.label : "口座番号"
    enabled : !gokeiyakubango.enabled
    onTextChanged : applyButton.enabled = true
  }

  TextField {
    id : gokeiyakubango
    Kirigami.FormData.checkable : true
    Kirigami.FormData.label : "ご契約番号"
    enabled : Kirigami.FormData.checked
    onTextChanged : applyButton.enabled = true
  }

  TextField {
    id : password
    Kirigami.FormData.label : i18n("パスワード")
    onTextChanged : applyButton.enabled = true
  }

  function applyConfig(spec) {
    var conf = spec.models[0].configuration
    gokeiyakubango.Kirigami.FormData.checked = (conf.factors == "1")
    tenban.text = conf.tenban
    kouzabango.text = conf.kouzabango
    gokeiyakubango.text = conf.gokeiyakubango
    password.text = conf.password
  }

  function saveConfig() {
    return {
      module : "mitsubishi",
      models : [
        {
          name : "mitsubishi/Model.qml",
          configuration : {
            factors : gokeiyakubango.enabled ? "1" : "2",
            tenban : tenban.text,
            kouzabango : kouzabango.text,
            gokeiyakubango : gokeiyakubango.text,
            password : password.text
          }
        }
      ],
      views : [
        {
          name : "mitsubishi/View.qml",
          configuration : ""
        }
      ]
    }
  }
}
