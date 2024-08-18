import QtQuick 2.12
import org.kde.plasma.core 2.0 as PlasmaCore
import "../../util.js" as Util

// Ideally this would be done in javascript but somebody decided that getting cookies in Javascript (the LANGUAGE, not just when it runs in a browser) is somehow a "security risk"
// and the cookies are therefore the one redacted header. This is idiotic but there doesn't seem to be a way to have it work, so use wget which doesn't have stupid arbitrary and senseless limitations
PlasmaCore.DataSource {
  id : dataFetcher
  engine : "executable"
  connectedSources : []
  signal startLoading()
  signal dataUpdated(error : string, amount : int)

  // Setup
  property string tenban
  property string kouzabango
  property string gokeiyakubango
  property string password

  // Credentials
  property string sequence_value
  property string session_id
  property string token
  property string iw_info

  // State
  enum FetchState {
    MaybeLoggedin,
    OpeningSession,
    LoggingIn,
    LoggedIn,
    Done
  }
  property int fetchState : Model.FetchState.Done
  property bool loading
  property string errorMessage : "Loading..."
  property int amount : 0

  // This property is used to ignore the result of an obsolete command. If start() is called while
  // a command is running, onNewData() will be called for it and it needs to be ignored.
  property string lastCmd
  function exec(cmd) {
    lastCmd = cmd
    connectSource(cmd)
  }
  onNewData : {
    if (sourceName != lastCmd) return // Obsolete command
    const out = data["stdout"]
    disconnectSource(sourceName)
    switch (fetchState) {
    case Model.FetchState.MaybeLoggedin :
      return interpretMaybeLoggedin(out)
    case Model.FetchState.OpeningSession :
      return interpretOpenSession(out)
    case Model.FetchState.LoggingIn :
      return interpretLogIn(out)
    case Model.FetchState.LoggedIn :
      return interpretLoggedIn(out)
    default :
      console.log("Mitsubishi : FetchState is unexpected : " + fetchState)
    }
  }

  function makeSequenceValue() {
    // const now = Math.floor(Date.now() / 1000)
    // const token = now + Math.floor(1000000 * Math.random)
    // return Digest::SHA256.hexdigest(token.toString(10))
    // Real code is supposed to do the above, but SHA256 digest is not available
    // in QML AFAICT. Make a random string ; I doubt the site can distinguish anyway
    var s = ""
    for (var i = 0; i < 64; ++i)
      s += Math.floor(Math.random() * 16).toString(16)
    return s
  }

  function reset() {
    session_id = null
    token = null
    iw_info = null
  }

  function start(force) {
    loading = true
    startLoading()
    fetchState = Model.FetchState.MaybeLoggedin
    fetchData()
  }

  function fetchData() {
    if (((!tenban || !kouzabango) && !gokeiyakubango) || !password) {
      outputLoginError(i18n("Configure"))
      return
    }

    // if !session_id || !token then fetchState can't be MaybeLoggedIn at the time of this writing, but it's still good prevention
    if ((!session_id || !token) && fetchState == Model.FetchState.MaybeLoggedIn) {
      fetchState = Model.FetchState.OpeningSession
      return openSession()
    }

    const url = "https://entry11.bk.mufg.jp/ib/dfw/APLLG/bff_lg/v1/ib/BFF_LG_0002_01"
    const payload = '{"drbSequenceValue":"R' + makeSequenceValue() + '"}'
    const command = "wget -O - -S --header='Content-Type: application/json' --header='CSRF-Token: " + token + "' --header='Cookie: X-DB-Session-Id=" + session_id + "; IW_INFO=" + iw_info + "' --post-data='" + payload + "' '" + url + "' 2>&1"
    exec(command)
  }

  function interpretMaybeLoggedin(data) {
    var value = (/"oazukariZandaka":(\d+)/gm).exec(data)
    if (!value) {
      console.log("Mitsubishi : credentials expired, logging in again")
      fetchState = Model.FetchState.OpeningSession
      openSession()
    } else {
      outputData(data)
    }
  }

  function openSession() {
    sequence_value = makeSequenceValue()
    const url = 'https://entry11.bk.mufg.jp/ibg/dfw/APLIN/bff_lgp/v1/ib/BFF_LG_0001_01'
    const payload = '{"drbSequenceValue":"R' + sequence_value + '"}'
    exec("wget --quiet -O - -S --header='Content-Type: application/json' --post-data='" + payload + "' '" + url + "' 2>&1")
  }

  function interpretOpenSession(data) {
    try {
      session_id = (/Set-Cookie: X-DB-Session-Id=([^;]+)/gm).exec(data)[1];
      token = (/Set-Cookie: drb-CSRF-Token=([^;]+)/gm).exec(data)[1];
    } catch (error) {
    }
    if (!session_id || !token) {
      console.log("Mitsubishi : couldn't open session")
      return outputLoginError()
    }
    fetchState = Model.FetchState.LoggingIn
    logIn()
  }

  function logIn() {
    const url = 'https://entry11.bk.mufg.jp/ibg/dfw/APLIN/bff_lgp/v1/ib/BFF_LG_0001_02'
    const payload = gokeiyakubango ?
          '{"keiyakuNo":"' + gokeiyakubango + '","loginPassword":"' + password + '","drbSequenceValue":"C' + sequence_value + '"}' :
          '{"kouzaNo":"' + kouzabango + '","tenban":"' + tenban + '","loginPassword":"' + password + '","drbSequenceValue":"C' + sequence_value + '"}'
    exec("wget -O - -S --header='Content-Type: application/json' --header='CSRF-Token: " + token + "' --header='Cookie: X-DB-Session-Id=" + session_id +"' --post-data='" + payload +"' '" + url + "' 2>&1")
  }

  function interpretLogIn(data) {
    try {
      session_id = (/Set-Cookie: X-DB-Session-Id=([^;]*)/gm).exec(data)[1];
      iw_info = (/Set-Cookie: IW_INFO=([^;]+)/gm).exec(data)[1];
    } catch (error) {
    }
    if (!iw_info) {
      console.log("Mitsubishi : couldn't log in")
      return outputLoginError()
    }
    fetchState = Model.FetchState.LoggedIn
    fetchData()
  }

  function interpretLoggedIn(data) {
    fetchState = Model.FetchState.Done
    var value = (/"oazukariZandaka":(\d+)/gm).exec(data)
    if (!value) {
      console.log("Mitsubishi : logged in successfully but couldn't fetch data")
      outputLoginError()
    } else {
      outputData(data)
    }
  }

  function outputLoginError(message) {
    updateData(message, 0)
  }

  function outputData(data) {
    var value = parseInt((/"oazukariZandaka":(\d+)/gm).exec(data)[1].toString())
    updateData(null, value)
  }

  function updateData(err, am) {
    loading = false
    errorMessage = err
    amount = am
    dataUpdated(err, am)
  }

  function configure(spec) {
    if (spec.factors == "1") {
      gokeiyakubango = spec.gokeiyakubango
    } else {
      tenban = spec.tenban
      kouzabango = spec.kouzabango
    }
    password = spec.password
    updateData(i18n("Loading..."), 0, 0)
    reset()
  }
}
