import QtQuick 2.6
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import "../../util.js" as Util

Item {
  id : top
  width : contents.width
  height : contents.height + top.parent.margin
  anchors.horizontalCenter : parent.horizontalCenter

  property var model
  property int urgency : 0

  MouseArea {
    anchors.fill : parent
    onClicked : {
      model.start(true)
    }
  }

  Row {
    id : contents
    anchors.verticalCenter : top.verticalCenter
    spacing : top.parent.margin
    width : icon.width + amountLabel.width + spacing
    height : col.height

    Image {
      id : icon
      anchors.verticalCenter : parent.verticalCenter
      width : sourceSize.width / 2
      height : sourceSize.height / 2
      source : "RSho.png"
    }

    ColumnLayout {
      id : col
      width : amountLabel.width
      height : amountLabel.height + plusvalueLabel.height + 2 * parent.margin
      anchors.verticalCenter : parent.verticalCenter

      PlasmaComponents.Label {
        id : amountLabel
        Layout.alignment : Qt.AlignHCenter | Qt.AlignTop

        font.bold : true
        font.pointSize : 10
        text : "Loading..."
      }
      PlasmaComponents.Label {
        id : plusvalueLabel
        Layout.alignment : Qt.AlignRight

        font.pointSize : 8
        color : "#ff0000"
        text : ""
      }
    }
  }

  PlasmaComponents.BusyIndicator {
    id : loading
    anchors.fill : parent
    visible : true
  }

  function startLoading() {
    loading.visible = true
  }

  function dataUpdated(error, amount, plusvalue, cash) {
    loading.visible = false
    if (error) {
      amountLabel.text = error
      plusvalueLabel.text = ""
    } else {
      amountLabel.text = Util.intToSeparatedString(amount)
      if (plusvalue > 0)
        plusvalueLabel.text = "+" + Util.intToSeparatedString(plusvalue)
      else
        plusvalueLabel.text = Util.intToSeparatedString(plusvalue)
    }
  }

  function configure(m, urgencyHandler, spec) {
    if (m.length != 1) throw new Error("Unexpected number of models for rakuten_shoken/ViewShoken : " + m.length)
    model = m[0]
    // Urgency can't change so no need to bind the handler
    model.dataUpdated.connect(dataUpdated)
    model.startLoading.connect(startLoading)
    dataUpdated(model.errorMessage, model.amount, model.plusvalue)
    loading.visible = model.loading
  }
}
