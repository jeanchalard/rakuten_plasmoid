import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.5
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
  id : configUpdates

  property alias cfg_updateIntervalVisible : updateIntervalVisible.value
  property alias cfg_updateIntervalHidden : updateIntervalHidden.value

  RowLayout {
    SpinBox {
      id : updateIntervalVisible
      stepSize : 1
      from : 5
      to : 1440
    }
    // TODO : this is broken because some languages may not have the
    // number before the unit. The most immediate way of fixing this is to
    // consider text for both labels in this RowLayout in conjunction, but
    // this means giving an ad-hoc translation for "minutes" which may not
    // be fine somewhere else, meaning something has to be done here
    Label {
      text : i18n("minutes")
    }
    Kirigami.FormData.label : i18n("Refresh interval for visible modules")
  }

  RowLayout {
    SpinBox {
      id : updateIntervalHidden
      stepSize : 1
      from : 5
      to : 1440
    }
    Label {
      text : i18n("minutes")
    }
    Kirigami.FormData.label : i18n("Refresh interval for hidden modules (minutes)")
  }
}
