geo = require "../index"
express = require "express"
assert = require "assert"

describe "geo.haversine", ->
  it "returns zero for the same points", (done) ->
    distance = geo.haversine({geometry: {location: {lat: 1, lng: 2}}}, {geometry: {location: {lat: 1, lng: 2}}})
    assert.equal(distance, 0)
    done()

  it "returns a correct distance between points", (done) ->
    distance = geo.haversine({geometry: {location: {lat: 38.898556, lng: -77.037852}}},
      {geometry: {location: {lat: 38.897147, lng: -77.043934}}})
    assert.equal(distance, 0.54915579120380840)
    done()

describe "geo.distance", ->
  before (done) ->
    process.env.GOOGLE_MAPS_API_URL = "http://localhost:3001"
    done()

  after (done) ->
    delete process.env.GOOGLE_MAPS_API_URL
    done()

  describe "when no services are running", ->
    it "should throw an error", (done) ->
      geo.distance "Kujawska 2, Gliwice", "Dworcowa 80, Gliwice", (error, result) ->
        assert(error)
        done()

  describe "when no directions service is running", ->
    server = null

    before (done) ->
      server = express.createServer()

      server.get "/maps/api/geocode/json", (request, response) ->
        response.json
          results: [
            geometry:
              location:
                lat: 1
                lng: 2
            address_components: [
              types: ["postal_code"]
              long_name: "44-100"
            ]
          ]

      server.get "/maps/api/directions/json", (request, response) ->
        response.json {}, 404

      server.listen 3001
      done()

    after (done) ->
      server.close()
      done()

    it "should throw an error if there is no connection", (done) ->
      geo.distance "Kujawska 2, Gliwice", "Dworcowa 80, Gliwice", (error, result) ->
        assert(error)
        done()

  describe "when geocode and directions services are running", ->
    server = null

    before (done) ->
      server = express.createServer()

      server.get "/maps/api/directions/json", (request, response) ->
        response.json
          routes: [
            legs: [
              distance:
                value: 20
            ]
          ]

      server.get "/maps/api/geocode/json", (request, response) ->
        response.json
          results: [
            geometry:
              location:
                lat: 1
                lng: 2
            address_components: [
              types: ["postal_code"]
              long_name: "44-100"
            ]
          ]

      server.listen 3001
      done()

    after (done) ->
      server.close()
      done()

    it "should calculate the distance", (done) ->
      geo.distance "Kujawska 2, Gliwice", "Dworcowa 80, Gliwice", (error, result) ->
        assert.equal(result?.distances?.driving, 20)
        done()
