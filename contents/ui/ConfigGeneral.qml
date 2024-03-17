import QtQuick 2.0
import QtQuick.Controls 1.3 as QQC1
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.1
import org.kde.kirigami 2.4 as Kirigami


Kirigami.FormLayout {
  Layout.fillWidth: true

  property alias cfg_login : login.text
  property alias cfg_password : password.text
  property alias cfg_updateInterval : interval.value

  TextField {
    id : login
    Kirigami.FormData.label : i18n("Login")
  }

  TextField {
    id : password
    Kirigami.FormData.label : i18n("Password")
  }

  QQC1.SpinBox {
    id : interval
    stepSize : 1
    minimumValue : 300
    Kirigami.FormData.label : i18n("Refresh interval (seconds)")
  }
}
