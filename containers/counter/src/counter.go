package main

import (
	"fmt"
	"github.com/garyburd/redigo/redis"
	"net/http"
	"os"
	"time"
)

var counter uint32
var redisCounter int

const counterKey string = "COUNTER"

func main() {
	counter = 0
	redisCounter = 0

	http.HandleFunc("/", handler)
	go http.ListenAndServe(":9000", nil)

	conn, err := redis.Dial("tcp", ":6379")
	for err != nil {
		conn, err = redis.Dial("tcp", ":6379")
		fmt.Fprintf(os.Stderr, "Could not connect to redis\n")
		time.Sleep(1 * time.Second)
	}
	defer conn.Close()

	ticker := time.NewTicker(1 * time.Second)
	for _ = range ticker.C {
		counter++

		// set to counter
		s, err := conn.Do("SET", counterKey, counter)
		if err != nil {
			fmt.Println("SET error:", err)
		} else {
			fmt.Println("SET:", s)
		}

		// get from redis
		v, err := redis.Int(conn.Do("GET", counterKey))
		if err != nil {
			fmt.Println("GET error:", err)
		} else {
			// and update
			redisCounter = v
			fmt.Println("GET", v)
		}
	}
}

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "%d", redisCounter)
}
