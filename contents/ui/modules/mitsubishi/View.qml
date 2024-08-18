import QtQuick 2.12
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
  // This seems necessary because on<Property>Changed is readonly AND cannot be
  // connect()ed to so it needs another property for no good reason
  property var urgencyChangedHandler : null
  onUrgencyChanged : { if (urgencyChangedHandler) urgencyChangedHandler() }

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
    height : amountLabel.height

    Image {
      id : icon
      anchors.verticalCenter : parent.verticalCenter
      width : sourceSize.width / 2
      height : sourceSize.height / 2
      source : "mufg.png"
    }

    PlasmaComponents.Label {
      id : amountLabel
      anchors.verticalCenter : parent.verticalCenter

      font.bold : true
      font.pointSize : 10
      text : "Loading..."
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

  function dataUpdated(error, amount) {
    loading.visible = false
    if (error) {
      amountLabel.text = error
      urgency = 0
    } else {
      amountLabel.text = Util.intToSeparatedString(amount)
      if (amount < 1000000)
        urgency = 2
      else if (amount < 3000000)
        urgency = 1
      else
        urgency = 0
    }
  }

  function configure(m, urgencyHandler, spec) {
    if (m.length != 1) throw new Error("Unexpected number of models for rakuten_shoken/ViewShoken : " + m.length)
    model = m[0]
    urgencyChangedHandler = urgencyHandler
    model.dataUpdated.connect(dataUpdated)
    model.startLoading.connect(startLoading)
    loading.visible = model.loading
    dataUpdated(model.errorMessage, model.amount)
  }
}
