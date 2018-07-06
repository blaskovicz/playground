package main

import (
	"encoding/json"
	"fmt"
	"io"
)

type functionArgs map[string]interface{}
type Function struct {
	cache *gobCache
}

func newFunction() (*Function, error) {
	cache, err := newGobCacheFromEnv()
	if err != nil {
		return nil, err
	}
	return &Function{
		cache: cache,
	}, nil
}

func writeFunctionError(err error, out io.Writer) {
	writeFunctionResponse(map[string]interface{}{"Error": err.Error()}, out)
}

func writeFunctionResponse(resp interface{}, out io.Writer) {
	json.NewEncoder(out).Encode(resp)
}

func parseFunctionArgs(in io.ReadCloser) (functionArgs, error) {
	fa := functionArgs{}
	return fa, json.NewDecoder(in).Decode(&fa)
}

func (f *Function) accept(in io.ReadCloser, out io.WriteCloser, errors io.WriteCloser) error {
	fa, err := parseFunctionArgs(in)
	if err != nil {
		return fmt.Errorf("invalid function args: %s", err)
	}
	m, ok := fa["Mode"]
	if !ok {
		return fmt.Errorf("missing mode")
	}
	mode, ok := m.(string)
	if !ok {
		return fmt.Errorf("invalid mode type")
	}

	body, _ := fa["Body"].(string)
	switch mode {
	case "compile":
		resp := &response{}
		key := cacheKey("prog", body)
		if err := f.cache.Get(key, resp); err != nil {
			resp, err = compileAndRun(&request{body})
			if err != nil {
				return err
			}
			f.cache.Set(key, resp)
		}
		writeFunctionResponse(resp, out)
	case "fmt", "format":
		imports, _ := fa["Imports"].(string)
		resp := fmtter(&fmtRequest{Imports: imports, Body: body})
		writeFunctionResponse(resp, out)
	default:
		return fmt.Errorf("unknown mode %s", mode)
	}

	return nil
}
func (f *Function) Accept(in io.ReadCloser, out io.WriteCloser, errors io.WriteCloser) {
	defer in.Close()
	defer out.Close()
	defer errors.Close()
	err := f.accept(in, out, errors)
	if err != nil {
		writeFunctionError(err, errors)
	}
}
