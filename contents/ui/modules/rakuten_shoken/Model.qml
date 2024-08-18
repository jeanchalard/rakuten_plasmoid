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
  signal dataUpdated(error : string, amount : int, plusvalue : int, cash : int)

  // Setup
  property string login
  property string password

  // Credentials
  property string cookie
  property string session

  enum FetchState {
    MaybeLoggedIn,
    LoggingIn,
    KnockingOnServer,
    LoggedIn,
    Done
  }
  property int fetchState : Model.FetchState.Done
  property bool loading : false
  property string errorMessage : "Loading..."
  property bool doneAtLeastOnce : false
  property int amount
  property int plusvalue
  property int cash

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
    case Model.FetchState.MaybeLoggedIn :
      return interpretMaybeLoggedIn(out)
    case Model.FetchState.LoggingIn :
      return interpretLoggingIn(out)
    case Model.FetchState.KnockingOnServer :
      return interpretKnockingOnServer(out)
    case Model.FetchState.LoggedIn :
      return interpretLoggedIn(out)
    default :
      console.log("RakutenShoken : FetchState is unexpected : " + fetchState)
    }
  }

  function reset() {
    cookie = null
    session = null
    doneAtLeastOnce = false
  }

  function start(force) {
    if (!force && doneAtLeastOnce) {
      const now = new Date()
      const day_of_week = now.getDay()
      if (day_of_week < 1 || day_of_week > 5) {
        console.log("Rakuten shoken : not running on day " + day_of_week)
        return
      }
      const hour = now.getHours()
      if (hour < 8 || hour > 16) {
        console.log("Rakuten shoken : not running at hour " + hour)
        return
      }
    }
    loading = true
    startLoading()
    fetchState = Model.FetchState.MaybeLoggedIn
    fetchData()
  }

  function fetchData() {
    if (!login || !password) {
      updateData(i18n("Configure"), 0, 0, 0)
      return
    }

    // if !cookie || !session then fetchState can't be MaybeLoggedIn at the time of this writing, but it's still good prevention
    if ((!cookie || !session) && fetchState == Model.FetchState.MaybeLoggedIn) {
      fetchState = Model.FetchState.LoggingIn
      return logIn()
    }

    exec("wget --quiet -O - --header=\"Cookie: checkTk=" + cookie + "\" \"https://member.rakuten-sec.co.jp/app/async_change_home_balance_lst.do;" + session + "?openCode=1\"");
  }

  function parseFetchedData(data) {
    try {
      var value = (/<p id="asset_total_amount"[^>]*>([^<]*)</gm).exec(data)[1]
      var pvalue = (/<p id="asset_total_amount_diff"[^>]*>([^<]*)</gm).exec(data)[1]
      // Use [\S\s] as a hack because . doesn't match new lines. Unless the 's' flag is given but that's evidently not supported in qml 🤯
      var cvalue = (/pcmm-m1-home-assets-section--money-bridge"[\S\s]*?<span class="pcmm-m1-home-assets-table__amount"[^>]*>([^<]*)</gm).exec(data)[1]
      if (!value || !pvalue || !cvalue) return null
      value = value.trim().replace(/\D/g, '')
      pvalue = pvalue.trim().replace(/\D/g, '')
      cvalue = cvalue.trim().replace(/\D/g, '')
      return { amount : parseInt(value), plusvalue : parseInt(pvalue), cash : parseInt(cvalue) }
    } catch (e) {
      return null
    }
  }

  function interpretMaybeLoggedIn(data) {
    var d = parseFetchedData(data);
    if (!d) {
      console.log("RakutenShoken : credentials expired, logging in again")
      fetchState = Model.FetchState.LoggingIn
      logIn()
    } else {
      fetchState = Model.FetchState.Done
      updateData(null, d.amount, d.plusvalue, d.cash)
    }
  }

  function logIn() {
    exec("wget --quiet -O - -S --post-data='loginid=" + login + "&passwd=" + encodeURIComponent(password) + "&memberPath=' 'https://member.rakuten-sec.co.jp/app/Login.do' 2>&1")
  }

  function interpretLoggingIn(data) {
    try {
      cookie = (/Set-Cookie: checkTk=([^;]+)/gm).exec(data)[1];
      session = (/location.href\s*=[^\?]*\?([^"]+)/gm).exec(data)[1];
    } catch (error) {
    }
    if (!cookie || !session) {
      fetchState = Model.FetchState.Done
      console.log("RakutenShoken : Couldn't log in")
      return updateData("Log in error", 0, 0, 0)
    }
    fetchState = Model.FetchState.KnockingOnServer
    knockOnServer()
  }

  function knockOnServer() {
    exec("wget --quiet -O - -S --header='Cookie: checkTk=" + cookie + "' 'https://member.rakuten-sec.co.jp/app/com_page_template.do;" + session + "?" + session + "'")
  }

  function interpretKnockingOnServer(data) {
    // No data to parse
    fetchState = Model.FetchState.LoggedIn
    fetchData()
  }

  function interpretLoggedIn(data) {
    var d = parseFetchedData(data);
    fetchState = Model.FetchState.Done
    if (!d) {
      console.log("RakutenShoken : logged in successfully but couldn't fetch data")
      updateData(i18n("Log in error"), 0, 0, 0)
    } else {
      updateData(null, d.amount, d.plusvalue, d.cash);
    }
  }

  function updateData(err, am, pv, c) {
    loading = false
    doneAtLeastOnce = true
    errorMessage = err
    amount = am
    plusvalue = pv
    cash = c
    dataUpdated(err, am, pv, c)
  }

  function configure(spec) {
    login = spec.login
    password = spec.password
    updateData(i18n("Loading..."), 0, 0, 0)
    reset()
  }
}
