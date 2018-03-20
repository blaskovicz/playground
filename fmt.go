// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/json"
	"fmt"
	"go/format"
	"net/http"
	"strings"

	"golang.org/x/tools/imports"
)

type fmtRequest struct {
	Imports string
	Body    string
}

type fmtResponse struct {
	Body  string
	Error string
}

func fmtter(req *fmtRequest) *fmtResponse {
	var out []byte
	var err error
	var resp fmtResponse
	if req.Imports != "" {
		out, err = imports.Process(progName, []byte(req.Body), nil)
	} else {
		out, err = format.Source([]byte(req.Body))
	}
	if err != nil {
		resp.Error = err.Error()
		// Prefix the error returned by format.Source.
		if !strings.HasPrefix(resp.Error, progName) {
			resp.Error = fmt.Sprintf("%v:%v", progName, resp.Error)
		}
	} else {
		resp.Body = string(out)
	}
	return &resp
}

func handleFmt(w http.ResponseWriter, r *http.Request) {
	req := fmtRequest{
		Body:    r.FormValue("body"),
		Imports: r.FormValue("imports"),
	}
	resp := fmtter(&req)
	json.NewEncoder(w).Encode(resp)
}
