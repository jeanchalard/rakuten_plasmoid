import QtQuick 2.0
import QtQuick.Controls 1.3 as QQC1
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.4 as Kirigami
import '../../util.js' as Util

Kirigami.FormLayout {
  anchors.left : parent.left
  anchors.right : parent.right

  property alias cfg_login : login.text
  property alias cfg_password : password.text

  Kirigami.Separator {
    Kirigami.FormData.label : "楽天証券"
    Kirigami.FormData.isSection : true
  }

  TextField {
    id : login
    Kirigami.FormData.label : i18n("Login")
    onTextChanged : applyButton.enabled = true
  }

  TextField {
    id : password
    Kirigami.FormData.label : i18n("Password")
    onTextChanged : applyButton.enabled = true
  }

  function applyConfig(spec) {
    var conf = spec.models[0].configuration
    login.text = conf.login
    password.text = conf.password
  }

  function saveConfig() {
    return {
      module : "rakuten_shoken",
      models : [
        {
          name : "rakuten_shoken/Model.qml",
          configuration : {
            login : login.text,
            password : password.text,
          }
        }
      ],
      views : [
        {
          name : "rakuten_shoken/ViewShoken.qml",
          configuration : ""
        },
        {
          name : "rakuten_shoken/ViewCash.qml",
          configuration : ""
        }
      ]
    }
  }
}
