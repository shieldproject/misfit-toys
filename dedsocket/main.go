package main

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"

	"github.com/gorilla/websocket"
	"github.com/jhunt/go-ansi"
	"github.com/shieldproject/shield/client/v2/shield"
	"golang.org/x/crypto/ssh/terminal"
)

// This program connects to the SHIELD websocket and then just doesn't read the
// buffer

func main() {
	if len(os.Args) < 2 {
		bailWith("positional argument <URL> is required")
	}
	targetURLStr := os.Args[1]
	targetURL, err := url.Parse(targetURLStr)
	if err != nil {
		bailWith("Could not parse URL: %s", err)
	}

	if targetURL.Scheme == "" {
		targetURL.Scheme = "http"
	} else if targetURL.Scheme != "http" && targetURL.Scheme != "https" {
		bailWith("Unknown scheme: %s", targetURL.Scheme)
	}

	if targetURL.Port() == "" {
		switch targetURL.Scheme {
		case "http":
			targetURL.Host = targetURL.Host + ":80"
		case "https":
			targetURL.Host = targetURL.Host + ":443"
		default:
			bailWith("Cannot determine URL port")
		}
	}

	shieldClient := shield.Client{
		URL:                targetURLStr,
		InsecureSkipVerify: true,
	}

	var username, password string
	fmt.Fprint(os.Stderr, "SHIELD Username: ")
	fmt.Scanln(&username)
	fmt.Fprint(os.Stderr, "SHIELD Password: ")
	passBytes, err := terminal.ReadPassword(int(os.Stdout.Fd()))
	fmt.Println("")
	if err != nil {
		bailWith("could not read password: %s", err)
	}
	password = string(passBytes)

	err = shieldClient.Authenticate(&shield.LocalAuth{
		Username: username,
		Password: password,
	})
	if err != nil {
		bailWith("failed to authenticate: %s", err)
	}

	websocketDialer := websocket.Dialer{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}

	headers := http.Header{}
	headers.Add("X-Shield-Session", shieldClient.Session)
	if targetURL.Scheme == "http" {
		targetURL.Scheme = "ws"
	} else {
		targetURL.Scheme = "wss"
	}
	targetURL.Path = "/v2/events"

	conn, _, err := websocketDialer.Dial(targetURL.String(), headers)
	if err != nil {
		bailWith("error when dialing: %s", err.Error())
	}

	netConn := conn.UnderlyingConn()
	tcpConn := netConn.(*net.TCPConn)
	fmt.Fprintf(os.Stderr, "Setting read buffer size\n")
	err = tcpConn.SetReadBuffer(4096)
	if err != nil {
		bailWith("Could not set read buffer size: %s", err)
	}
	fmt.Fprintf(os.Stderr, "Successfully set buffer size\n")

	quitChan := make(chan bool)

	go func() {
		for {
			fmt.Fprintf(os.Stderr, "Type `quit' to exit: ")
			var input string
			fmt.Scanln(&input)
			if input == "quit" || input == "exit" {
				quitChan <- true
				break
			}
		}
	}()

	<-quitChan
	conn.Close()
}

func bailWith(format string, args ...interface{}) {
	_, err := ansi.Fprintf(os.Stderr, "@R{"+format+"}\n", args...)
	if err != nil {
		panic(fmt.Sprintf(format, args...))
	}
	os.Exit(1)
}
