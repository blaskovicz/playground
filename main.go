// Copyright 2013 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"

	"cloud.google.com/go/compute/metadata"
	"cloud.google.com/go/datastore"
	swarmed "github.com/blaskovicz/go-swarmed"
)

var log = newStdLogger()

func main() {
	if err := swarmed.LoadSecretsWithOpts("playground-golang", true); err != nil {
		log.Fatalf("Error loading secrets: %v", err)
	}
	mode := os.Getenv("playground_mode")
	if mode == "" {
		mode = "server"
	}
	switch mode {
	case "server":
		s, err := newServer(func(s *server) error {
			pid := projectID()
			if pid == "" {
				s.db = &inMemStore{}
			} else {
				c, err := datastore.NewClient(context.Background(), pid)
				if err != nil {
					return fmt.Errorf("could not create cloud datastore client: %v", err)
				}
				s.db = cloudDatastore{client: c}
			}
			var err error
			s.cache, err = newGobCacheFromEnv()
			if err != nil {
				return fmt.Errorf("could not create cache client: %v", err)
			}
			s.log = log
			return nil
		})

		if err != nil {
			log.Fatalf("Error creating server: %v", err)
		}

		if len(os.Args) > 1 && os.Args[1] == "test" {
			s.test()
			return
		}

		port := os.Getenv("PORT")
		if port == "" {
			port = "8080"
		}
		log.Printf("Listening on :%v ...", port)
		log.Fatalf("Error listening on :%v: %v", port, http.ListenAndServe(":"+port, s))
	case "function":
		f, err := newFunction()
		if err != nil {
			log.Fatalf("Error creating function: %v", err)
		}
		f.Accept(os.Stdin, os.Stdout, os.Stderr)
	default:
		panic(fmt.Errorf("mode %s not implemented", mode))
	}
}

func projectID() string {
	id, err := metadata.ProjectID()
	if err != nil && os.Getenv("GAE_INSTANCE") != "" {
		log.Fatalf("Could not determine the project ID: %v", err)
	}
	return id
}
