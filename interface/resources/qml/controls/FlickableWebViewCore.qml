import QtQuick 2.7
import QtWebView 1.1
import QtWebChannel 1.0

import QtQuick.Controls 2.2

import stylesUit 1.0 as StylesUIt

Item {
    id: flick

    property alias url: webViewCore.url
    property alias canGoBack: webViewCore.canGoBack
    property alias webViewCore: webViewCore
    property alias webViewCoreProfile: webViewCore.profile
    property string webViewCoreUserAgent

    property string userScriptUrl: ""
    property string urlTag: "noDownload=false";

    signal newViewRequestedCallback(var request)
    signal loadingChangedCallback(var loadRequest)


    width: parent.width

    property bool interactive: false

    property bool blurOnCtrlShift: true

    StylesUIt.HifiConstants {
        id: hifi
    }

    function stop() {
        webViewCore.stop();
    }

    Timer {
        id: delayedUnfocuser
        repeat: false
        interval: 200
        onTriggered: {

            // The idea behind this is to delay unfocusing, so that fast lower/raise will not result actual unfocusing.
            // Fast lower/raise happens every time keyboard is being re-raised (see the code below in OffscreenQmlSurface::setKeyboardRaised)
            //
            // if (raised) {
            //    item->setProperty("keyboardRaised", QVariant(!raised));
            // }
            //
            // item->setProperty("keyboardRaised", QVariant(raised));
            //

            webViewCore.runJavaScript("if (document.activeElement) document.activeElement.blur();", function(result) {
                console.log('unfocus completed: ', result);
            });
        }
    }

    function unfocus() {
        delayedUnfocuser.start();
    }

    function stopUnfocus() {
        delayedUnfocuser.stop();
    }

    function onLoadingChanged(loadRequest) {
        if (WebView.LoadStartedStatus === loadRequest.status) {

            // Required to support clicking on "hifi://" links
            var url = loadRequest.url.toString();
            url = (url.indexOf("?") >= 0) ? url + urlTag : url + "?" + urlTag;
            if (urlHandler.canHandleUrl(url)) {
                if (urlHandler.handleUrl(url)) {
                    webViewCore.stop();
                }
            }
        }

        if (WebView.LoadFailedStatus === loadRequest.status) {
            console.log("Tablet Web View failed to load url: " + loadRequest.url.toString());
        }

        if (WebView.LoadSucceededStatus === loadRequest.status) {
            //disable Chromium's scroll bars
        }
    }

    WebView {
        id: webViewCore

        width: parent.width
        height: parent.height

        settings.pluginsEnabled: true
        settings.touchIconsEnabled: true
        settings.allowRunningInsecureContent: true

        Component.onCompleted: {
            webChannel.registerObject("eventBridge", eventBridge);
            webChannel.registerObject("eventBridgeWrapper", eventBridgeWrapper);

            if (webViewCoreUserAgent !== undefined) {
                webViewCore.profile.httpUserAgent = webViewCoreUserAgent
            } else {
                webViewCore.profile.httpUserAgent += " (HighFidelityInterface)";
            }
            // Ensure the JS from the web-engine makes it to our logging
            webViewCore.javaScriptConsoleMessage.connect(function(level, message, lineNumber, sourceID) {
                console.log("Web Entity JS message: " + sourceID + " " + lineNumber + " " +  message);
            });
        }

        onFeaturePermissionRequested: {
            grantFeaturePermission(securityOrigin, feature, true);
        }

        //disable popup
        onContextMenuRequested: {
            request.accepted = true;
        }

        onNewViewRequested: {
            newViewRequestedCallback(request)
        }

        // Prior to 5.10, the WebEngineView loading property is true during initial page loading and then stays false
        // as in-page javascript adds more html content. However, in 5.10 there is a bug such that adding html turns
        // loading true, and never turns it false again. safeLoading provides a workaround, but it should be removed
        // when QT fixes this.
        property bool safeLoading: false
        property bool loadingLatched: false
        property var loadingRequest: null
        onLoadingChanged: {
            webViewCore.loadingRequest = loadRequest;
            webViewCore.safeLoading = webViewCore.loading && !loadingLatched;
            webViewCore.loadingLatched |= webViewCore.loading;
         }
        onSafeLoadingChanged: {
            flick.onLoadingChanged(webViewCore.loadingRequest)
            loadingChangedCallback(webViewCore.loadingRequest)
        }
    }

    AnimatedImage {
        //anchoring doesnt works here when changing content size
        x: flick.width/2 - width/2
        y: flick.height/2 - height/2
        source: "../../icons/loader-snake-64-w.gif"
        visible: webViewCore.safeLoading && /^(http.*|)$/i.test(webViewCore.url.toString())
        playing: visible
        z: 10000
    }

    Keys.onPressed: {
        if (blurOnCtrlShift && (event.modifiers & Qt.ShiftModifier) && (event.modifiers & Qt.ControlModifier)) {
            webViewCore.focus = false; 
        }
    }
}
