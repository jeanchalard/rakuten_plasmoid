import QtQuick 2.12
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import "util.js" as Util

Rectangle {
  id : root
  // Prefer the full representation when on the desktop (Floating) and the compact otherwise (in a panel, or on a mobile device)
  Plasmoid.preferredRepresentation : plasmoid.location == PlasmaCore.Types.Floating ? Plasmoid.fullRepresentation : Plasmoid.compactRepresentation

  // Shortcut to expand
  readonly property bool expanded : plasmoid.expanded
  // The "spec" setting, which contains the modules specification in a bizarre format. The format essentially is based on "LenString"s, which is
  // a string with a decimal int followed by a single ';' then the string. E.g. "foo" would be encoded as "3;foo". This allows for avoiding the
  // complexity of escaping separators, as modules are responsible for supplying their own configuration specs and can include any char
  // they want in them. See 'util.js' for encoding and decoding helpers.
  readonly property string spec : plasmoid.configuration.spec
  // updateIntervals in minutes. These represent how long the interval between automatic updates of data for visible and hidden views,
  // respectively. E.g. if the plasmoid is in a panel it shows only one module at a time. That module is "visible" and will update every
  // updateintervalVisible minutes (default 5 minutes). Other modules are hidden and will update every updateIntervalHiddden minutes
  // (default 6 hours). It is useful to update the hidden widgets because when the data updates they might signal themselves as "urgent"
  // and be displayed in the compact representation as a matter of priority.
  readonly property int updateIntervalVisible : plasmoid.configuration.updateIntervalVisible
  readonly property int updateIntervalHidden : plasmoid.configuration.updateIntervalHidden

  property var compactRepresentation : null
  property var fullRepresentation : null

  // List of models, key being the model (directory) name and value being the object.
  // TODO : when the spec is changed, the models that are no longer in the spec are not removed
  // which is bad because they'll continue fetching their data.
  property var models : new Object()
  function getModel(component) {
    var model = models[component]
    if (!model) {
      var comp = Qt.createComponent(component)
      if (comp.errorString()) {
        console.log("Error loading model for " + component + " : " + comp.errorString)
      } else {
        model = comp.createObject(root)
        models[component] = model
      }
    }
    return model
  }
  // Create (if needed) and configure the models. Even if a model is already created, it will be
  // configured again when the spec changes. However this happens even if the spec didn't
  // change for that model because the code below doesn't particularly check if it changed.
  // It's arguable whether this is the right behavior ; after all a user that goes and changes the
  // configuration for one module may expect all modules to restart.
  onSpecChanged : {
    var spec = JSON.parse(Plasmoid.configuration["spec"])
    spec.modules.forEach((m) => {
      m.models.forEach((md) => {
        var model = getModel("modules/" + md.name)
        console.log("Configure and start model " + m.module + " : " + model)
        model.configure(md.configuration)
        model.start()
      })
    })

    lastVisibleCheck = new Date()
    lastHiddenCheck = new Date()
    timer.restart()
  }

  property var viewToModels : new Map()

  // The component for the compact view. This loads all views, but sets all of them to
  // visible = false except the first one. The point is that the invisible views can still set
  // themselves as urgent to be shown instead of any non-urgent view. And possibly
  // someday scroll through the view with the mouse wheel.
  Plasmoid.compactRepresentation : Item {
    id : compactRoot
    Layout.minimumWidth : compactRoot.childrenRect.width

    // Shortcut for spec, also allows the |onSpecChanged| slot below.
    readonly property string spec : plasmoid.configuration.spec
    onSpecChanged : buildUi()

    Rectangle {
      id : urgentBackground
      anchors.fill : zandakaMain
      color : "transparent"
    }
    // Item to receive the children. This is useful so that the mouse area below is above all
    // of them so a click can't be intercepted.
    Item {
      id : zandakaMain
      width : childrenRect.width
      height : parent.height
      readonly property int margin : 10
    }

    // MouseArea to detect clicks on the compact widget. When clicked, the widget expands
    // to the full representation.
    MouseArea {
      anchors.fill : parent
      onClicked : {
        if (mouse.button == Qt.LeftButton) {
          plasmoid.expanded = !plasmoid.expanded;
        }
      }
      // WheelDelta idea and some impl shamelessly lifted from org.kde.plasma.eventcalendar,
      // which is GPL like this code
      property int wheelDelta : 0
      onWheel: {
        var delta = wheel.angleDelta.y || wheel.angleDelta.x;
        wheelDelta += delta;
        // Magic number 120 for common "one click"
        // See: https://doc.qt.io/qt-6/qml-qtquick-wheelevent.html#angleDelta-prop
        while (wheelDelta >= 120) {
          wheelDelta -= 120
          showPreviousView()
        }
        while (wheelDelta <= -120) {
          wheelDelta += 120
          showNextView()
        }
      }
    }

    function visibleChildIndex() {
      for (var i = 0; i < zandakaMain.children.length; ++i) {
        if (zandakaMain.children[i].visible) return i
      }
      return -1
    }

    // TODO : animate
    function showPreviousView() {
      var i = visibleChildIndex();
      if (-1 == i) return // supposed to be impossible
      zandakaMain.children[i].visible = false
      if (0 == i) i = zandakaMain.children.length - 1
      else --i
      zandakaMain.children[i].visible = true
      urgentBackground.color = zandakaMain.children[i].urgency > 0 ? "red" : "transparent"
    }

    // TODO : animate
    function showNextView() {
      var i = visibleChildIndex();
      if (-1 == i) return // supposed to be impossible
      zandakaMain.children[i].visible = false
      i = (i + 1) % zandakaMain.children.length
      zandakaMain.children[i].visible = true
      urgentBackground.color = zandakaMain.children[i].urgency > 0 ? "red" : "transparent"
    }

    function reevaluateUrgencies(from) {
      if (undefined == from) from = 0
      var childToShow = zandakaMain.children[from]
      for (var i = from; i < zandakaMain.children.length; ++i) {
        var child = zandakaMain.children[i]
        if (child.urgency > childToShow.urgency) childToShow = child
        child.visible = false
      }
      childToShow.visible = true
      urgentBackground.color = childToShow.urgency > 0 ? "red" : "transparent"
    }

    function buildUi() {
      compactRepresentation = this

      var originalChildrenCount = zandakaMain.children.length
      for (var i = 0; i < zandakaMain.children.length; ++i) {
        viewToModels.delete(zandakaMain.children[i])
        zandakaMain.children[i].destroy()
      }

      var childToShow = null
      var spec = Util.decodeSpec(Plasmoid.configuration["spec"])
      spec.modules.forEach((module) => {
        console.log("Instantiate " + module.module)
        var models = module.models.map((m) => getModel("modules/" + m.name))
        module.views.forEach((v) => {
          var comp = Qt.createComponent("modules/" + v.name)
          if (comp.errorString()) {
            console.log("Error loading " + component + " : " + comp.errorString)
          } else {
            var obj = comp.createObject(zandakaMain)
            viewToModels.set(obj, models)
            obj.configure(models, reevaluateUrgencies, v.configuration)
          }
        })
      })
      // Since the original children haven't been removed yet, should evaluate starting
      // with the first that was just added
      reevaluateUrgencies(originalChildrenCount)
    }
  }

  // The component for the full representation. This is shown when the widget is put directly
  // on the desktop, or in a floating window when the compact representation is clicked (like
  // many other widgets).
  // It just shows the list of all configured modules, separated by a separator (see the definition
  // of the separator below).
  Plasmoid.fullRepresentation : Column {
    id : zandakaList
    Layout.minimumWidth : zandakaList.childrenRect.width + 2 * margin
    Layout.minimumHeight : zandakaList.childrenRect.height
    anchors.leftMargin : margin
    anchors.rightMargin : 2 * margin
    readonly property string spec : plasmoid.configuration.spec
    onSpecChanged : buildUi()

    // Margin for all modules. The view of the modules are encouraged to use this to lay
    // themselves out.
    readonly property int margin : 20

    function buildUi() {
      fullRepresentation = this

      // Because destroy() doesn't remove the child immediately, remember the original
      // count to know whether to add a separator.
      const originalChildrenCount = zandakaList.children.length
      for (var i = 0; i < zandakaList.children.length; ++i) {
        viewToModels.delete(zandakaList.children[i])
        zandakaList.children[i].destroy() // Destroy the component or the separator
      }

      var spec = Util.decodeSpec(Plasmoid.configuration["spec"])
      spec.modules.forEach((module) => {
        console.log("Instantiate " + module.module)
        var models = module.models.map((m) => getModel("modules/" + m.name))
        module.views.forEach((v) => {
          if (zandakaList.children.length != originalChildrenCount)
            separator.createObject(zandakaList)
          var comp = Qt.createComponent("modules/" + v.name)
          if (comp.errorString()) {
            console.log("Error loading " + module.module + "(" + v.name + ") : " + comp.errorString)
          } else {
            var obj = comp.createObject(zandakaList)
            viewToModels.set(obj, models)
            obj.configure(models, null /* urgencyHandler */, v.configuration)
          }
        })
      })
    }
  }

  // The separator between modules in the fullRepresentation form. This is meant to be
  // a 1-px high line of a grey gradient color with spaces on each side. It is a Component
  // so it can be dynamically loaded once for each separator between modules.
  Component {
    id : separator
    Rectangle {
      height : 1
      width : parent.width * 0.9
      anchors.horizontalCenter : parent.horizontalCenter
      gradient : Gradient {
        orientation : Gradient.Horizontal
        GradientStop { position : 0.0; color : "#505050" }
        GradientStop { position : 0.5; color : "#F0F0F0" }
        GradientStop { position : 1.0; color : "#505050" }
      }
    }
  }

  // Timer fires once every minute to check whether it's time to update the models.
  // This is because how timers work :
  // - There are claims on Internet that timers work only up to 10 minutes. Didn't try but
  // - Timers are running on the animation loop, meaning if they are not displayed they
  //   don't run. This is undesirable for this use case, where really the data should be
  //   updated in the background so as to be ready to be displayed immediately. Checking
  //   every minute still isn't doing quite that, but at least it will update at most one minute
  //   after being displayed, which can be considerably better if the delay is set to a long
  //   time (by default the hidden timer is 6 hours, it would be a really poor idea).
  // - Timers also don't run while the computer is sleeping, as in if it's set to 5 minutes and
  //   one minute in the computer goes to sleep the timer will fire 4 minutes after waking
  //   up. Again this is unhelpful in this app, where the timer may fire once in the evening
  //   just before the user puts the computer to sleep, and as she turns the computer on
  //   again in the morning she really doesn't want to wait another 6 hours until the next
  //   update.
  // The simplest solution seems to be to fire the timer often to check if the time has
  // elapsed using a wall clock. This implementation checks every minute as a tradeoff,
  // since checking every second or more ofter, no matter how light the check is, will tax
  // the battery if on a laptop or mobile device, and even on a desktop consume more
  // CPU than useful.
  //
  // Note that models are free to ignore some calls to start(). For example, the Rakuten Shoken
  // model will not honor starts at night and on saturdays and sundays because the marketplace
  // is closed at these times (unless it never fetched the data).
  property date lastVisibleCheck : new Date(0) // epoch, so that the check will fire immediately
  property date lastHiddenCheck : new Date(0)
  Timer {
    id : timer
    interval : 60 * 1000 // One minute
    running : false // Will be started as part of configuration change listener
    repeat : true
    onTriggered : {
      const now = new Date()
      var modelsToUpdate = []
      // updateIntervalVisible is in minutes
      if (now - lastVisibleCheck > (updateIntervalVisible * 60 * 1000)) {
        viewToModels.forEach((value, key, map) => { if (isVisible(key)) {
          value.forEach((model) => { if (!modelsToUpdate.includes(model)) modelsToUpdate.push(model) })
        }})
        lastVisibleCheck = now
      }
      if (now - lastHiddenCheck > (updateIntervalHidden * 60 * 1000)) {
        viewToModels.forEach((value, key, map) => { if (!isVisible(key)) {
          value.forEach((model) => { if (!modelsToUpdate.includes(model)) modelsToUpdate.push(model) })
        }})
        lastHiddenCheck = now
      }
      modelsToUpdate.forEach((item, index, array) => { item.start(false) })
    }
  }

  function isVisible(item) {
    while (item != null && item != compactRepresentation && item != fullRepresentation) {
      if (!item.visible) return false
      item = item.parent
    }
    if (item == null) return false
    // Compact is shown if the preferred representation is compact
    if (item == compactRepresentation) return Plasmoid.preferredRepresentation == Plasmoid.compactRepresentation
    // Full is shown if it's preferred or the widget is currently expanded
    return Plasmoid.preferredRepresentation == Plasmoid.fullRepresentation || expanded
  }
}
