// Copyright 2017 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"bytes"
	"encoding/gob"
	"fmt"
	"os"
	"strings"

	"github.com/bradfitz/gomemcache/memcache"
	"github.com/go-redis/redis"
)

var ErrNoSuchKey = fmt.Errorf("No such cache key")

type gobCacheClient interface {
	Set(key string, b []byte) error
	Get(key string) ([]byte, error)
}

// gobCache stores and retrieves values using a memcache client using the gob
// encoding package. It does not currently allow for expiration of items.
// With a nil gobCache, Set is a no-op and Get will always return memcache.ErrCacheMiss.
type gobCache struct {
	client gobCacheClient
}

func newGobCacheFromEnv() (*gobCache, error) {
	var addr string
	if lAddr := os.Getenv("MEMCACHED_ADDR"); lAddr != "" {
		if !strings.HasPrefix(lAddr, "memcached://") {
			lAddr = "memcached://" + lAddr
		}
		addr = lAddr
	} else if lAddr := os.Getenv("REDIS_ADDR"); lAddr != "" {
		if !strings.HasPrefix(lAddr, "redis://") {
			lAddr = "redis://" + lAddr
		}
		addr = lAddr
	} else if lAddr := os.Getenv("CACHE_URL"); lAddr != "" {
		addr = lAddr
	}
	// else, empty
	return newGobCache(addr)
}

func newGobCache(addr string) (*gobCache, error) {
	var c gobCacheClient
	var err error
	if addr == "" {
		c, err = newNullGobCacheClient()
	} else if !strings.Contains(addr, "://") || strings.HasPrefix(addr, "memcached://") {
		c, err = newMemcacheGobCacheClient(addr)
	} else if strings.HasPrefix(addr, "redis://") {
		c, err = newRedisGobCacheClient(addr)
	} else {
		err = fmt.Errorf("Unkown cache type: %s", addr)
	}
	if err != nil {
		return nil, err
	}
	return &gobCache{client: c}, nil
}

// Set will marshal and call the underlying backend writer
func (c *gobCache) Set(key string, v interface{}) error {
	if c == nil || c.client == nil {
		return nil
	}
	var buf bytes.Buffer
	if err := gob.NewEncoder(&buf).Encode(v); err != nil {
		return err
	}
	return c.client.Set(key, buf.Bytes())
}

// Get will unmarshal after calling the underlying backend reader
func (c *gobCache) Get(key string, v interface{}) error {
	if c == nil || c.client == nil {
		return ErrNoSuchKey
	}
	val, err := c.client.Get(key)
	if err != nil {
		return err
	}
	return gob.NewDecoder(bytes.NewReader(val)).Decode(v)
}

// null client does nothing besides implement the interface
type nullGobCacheClient struct{}

func newNullGobCacheClient() (*nullGobCacheClient, error) {
	return &nullGobCacheClient{}, nil
}
func (n *nullGobCacheClient) Set(key string, b []byte) error { return nil }
func (n *nullGobCacheClient) Get(key string) ([]byte, error) { return nil, ErrNoSuchKey }

// memcached client wraps a memcached backend
type memcacheGobCacheClient struct {
	client *memcache.Client
}

func newMemcacheGobCacheClient(addr string) (*memcacheGobCacheClient, error) {
	c := memcache.New(strings.TrimPrefix(addr, "memcached://"))
	return &memcacheGobCacheClient{client: c}, nil
}
func (m *memcacheGobCacheClient) Set(key string, b []byte) error {
	return m.client.Set(&memcache.Item{Key: key, Value: b})
}
func (m *memcacheGobCacheClient) Get(key string) ([]byte, error) {
	item, err := m.client.Get(key)
	if err != nil {
		if err == memcache.ErrCacheMiss {
			return nil, ErrNoSuchKey
		}
		return nil, err
	}
	return item.Value, nil
}

// redis client wraps a redis backend
type redisGobCacheClient struct {
	client *redis.Client
}

// eg: redis://:qwerty@localhost:6379/1
func newRedisGobCacheClient(addr string) (*redisGobCacheClient, error) {
	opt, err := redis.ParseURL(addr)
	if err != nil {
		return nil, err
	}
	c := redis.NewClient(opt)
	_, err = c.Ping().Result()
	return &redisGobCacheClient{client: c}, err
}
func (r *redisGobCacheClient) Set(key string, b []byte) error {
	return r.client.Set(key, b, 0).Err()
}
func (r *redisGobCacheClient) Get(key string) ([]byte, error) {
	val, err := r.client.Get(key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return nil, ErrNoSuchKey
		}
		return nil, err
	}
	return val, nil
}
