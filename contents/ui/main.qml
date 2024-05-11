import QtQuick 2.6
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0

Rectangle {
  id : root
  anchors.fill : parent
  Plasmoid.preferredRepresentation : Plasmoid.fullRepresentation
  color : "transparent"
  Layout.minimumWidth : Math.max(amount.implicitWidth, plusvalue.implicitWidth)

  readonly property string login : plasmoid.configuration.login
  readonly property string password : plasmoid.configuration.password
  readonly property int updateInterval : plasmoid.configuration.updateInterval
  onLoginChanged : start()
  onPasswordChanged : start()
  onUpdateIntervalChanged : start()
  MouseArea {
    anchors.fill : parent
    onClicked : start()
  }

  property var credentials : {}
  property var loaded : false

  // Ideally this would be done in javascript but somebody decided that getting cookies in Javascript (the LANGUAGE, not just when it runs in a browser) is somehow a "security risk"
  // and the cookies are therefore the one redacted header. This is idiotic but there doesn't seem to be a away to have it work, so use wget which doesn't have stupid arbitrary and senseless limitations
  PlasmaCore.DataSource {
    id : loginCommand
    engine : "executable"
    connectedSources : []
    onNewData : {
      console.log("Ran log in command")
      exited(data["stdout"])
      disconnectSource(sourceName)
    }
    signal exited(string value)
    function run() {
      connectSource("wget --quiet -O - -S --post-data='loginid=" + login + "&passwd=" + encodeURIComponent(password) + "&memberPath=' 'https://member.rakuten-sec.co.jp/app/Login.do' 2>&1")
    }
  }
  Connections {
    target : loginCommand
    function onExited(value) {
      credentials = parseLoggedInValues(value);
      if (null == credentials) {
        console.log("Couldn't log in");
        displayLoginError();
      }
      console.log("Session " + credentials.session);
      console.log("Cookie " + credentials.cookie);
      knockOnServer.run(credentials.session, credentials.cookie);
    }
  }

  PlasmaCore.DataSource {
    id : knockOnServer
    engine : "executable"
    connectedSources : []
    onNewData : {
      console.log("Knocked on server")
      exited(data["stdout"])
      disconnectSource(sourceName)
    }
    signal exited()
    function run(session, cookie) {
      connectSource("wget --quiet -O - -S --header='Cookie: checkTk=" + cookie + "' 'https://member.rakuten-sec.co.jp/app/com_page_template.do;" + session + "?" + session + "'")
    }
  }
  Connections {
    target : knockOnServer
    function onExited() {
      fetchDataCommand.run(credentials.session, credentials.cookie);
    }
  }

  PlasmaCore.DataSource {
    id : fetchDataCommand
    engine : "executable"
    connectedSources : []
    onNewData : {
      exited(data["stdout"])
      disconnectSource(sourceName)
    }
    signal exited(string value)
    function run(session, cookie) {
      connectSource("wget --quiet -O - --header=\"Cookie: checkTk=" + cookie + "\" \"https://member.rakuten-sec.co.jp/app/async_change_home_balance_lst.do;" + session + "?openCode=1\"");
    }
  }
  Connections {
    target : fetchDataCommand
    function onExited(value) {
      console.log("Fetched data")
      var data = parseData(value);
      displayData(data.amount, data.plusvalue);
    }
  }

  function parseLoggedInValues(text) {
    try {
      var cookie = (/Set-Cookie: checkTk=([^;]+)/gm).exec(text)[1];
      var session = (/location.href\s*=[^\?]*\?([^"]+)/gm).exec(text)[1];
      if (null == cookie || null == session || undefined == cookie || undefined == session) return null;
      return { cookie : cookie, session : session };
    } catch (error) {
      return null;
    }
  }

  function parseData(text) {
    var value = (/<p id="asset_total_amount"[^>]*>([^<]*)</gm).exec(text)[1];
    var pvalue = (/<p id="asset_total_amount_diff"[^>]*>([^<]*)</gm).exec(text)[1];
    return { amount : value.trim(), plusvalue : pvalue.trim() };
  }

  function displayData(av, pv) {
    loaded = true;
    amount.text = av;
    plusvalue.text = pv;
  }

  function displayLoginError() {
    loaded = false;
    amount.text = "Log in error";
    plusvalue.text = "";
  }

  function start() {
    console.log("Loaded, login " + login + " / " + encodeURIComponent(password))
    if (login == "" || password == "")
      amount.text = i18n("Configure")
    else {
      if (!loaded) amount.text = i18n("Loading...")
      loginCommand.run();
    }
  }

  Component.onCompleted : {
    // Somehow this must wait for the component to have completed to run ? If run immediately it seems to kill the process before it's done for some reason.
    start();
  }

  ColumnLayout {
    anchors.fill : parent
    PlasmaComponents.Label {
      id : amount
      Layout.alignment : Qt.AlignHCenter | Qt.AlignTop

      font.bold : true
      font.pointSize : 10
      text : ""
    }
    PlasmaComponents.Label {
      id : plusvalue
      width : root.width
      Layout.alignment : Qt.AlignRight

      font.pointSize : 8
      color : "#ff0000"
      text : ""
    }
  }

  Timer {
    interval : updateInterval * 1000
    running : true
    repeat : true
    onTriggered : {
      const now = new Date()
      console.log(now)
      const day_of_week = now.getDay()
      if (day_of_week < 1 || day_of_week > 5) {
        console.log("Wrong day " + day_of_week)
        return
      }
      const hour = now.getHours()
      if (hour < 8 || hour > 17) {
        console.log("Wrong hour " + hour)
        return
      }
      loginCommand.run();
    }
  }
}
