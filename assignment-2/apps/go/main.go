// CLO835 Assignment 2 — Go starter
// This is VERSION 0.2. To release VERSION 0.3, change message below to:
//   "Hello world from the CLO835 class and <YOUR_STUDENT_ID>!"
// (replace <YOUR_STUDENT_ID> with your own Seneca student ID, e.g. 10112233)
package main

import (
	"fmt"
	"log"
	"net/http"
)

const (
	version = "0.2"
	message = "Hello world from the CLO835 class!"
	port    = ":8080"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, message)
	})
	// for the bonus probes
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })

	log.Printf("CLO835 app v%s listening on %s", version, port)
	log.Fatal(http.ListenAndServe(port, nil))
}
