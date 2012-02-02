geo = require '../index'
express = require 'express'
should = require 'should'

describe 'Tiramizoo geo service', ->
  before (done) ->
    process.env.GOOGLE_MAPS_API_URL = 'http://localhost:3001'
    done()

  after (done) ->
    delete process.env.GOOGLE_MAPS_API_URL
    done()

  describe "when calculating route distance", ->
    it "should throw an error if there is no connection", (cbk) ->
      geo.routeDistance "200,2", "300,3", (err, result) ->
        should.exist(err)
        cbk()

    describe "when server is running", (cbk) ->
      server = null

      before (done) ->
        server = express.createServer()

        server.get '/maps/api/directions/json', (req, res) ->
          res.json {routes: [{legs: [{distance: {value: 20}}]}]}

        server.listen 3001
        done()

      after (done) ->
        server.close()
        done()

      it "should calculate the distance", (cbk) ->
        geo.routeDistance "1,1", "2,2", (err, result) ->
          result.distance?.should.equal 20
          cbk()

  describe "when using the geocoder", ->
    it "should throw an error if there is no connection", (cbk) ->
      geo.geocode {test: 2}, (err, result) ->
        should.exist err
        cbk()

    describe "when server is running", ->
      server = null

      before (done) ->
        server = express.createServer()
        server.get '/maps/api/geocode/json', (req, res) ->
          if req.param('address') == 'error'
            res.send "INTERNAL SERVER ERROR", 500
          else
            res.json {results: [{geometry: {location: {lat: 1, lng: 2}}}]}
        server.listen 3001
        done()

      after (done) ->
        server.close()
        done()

      it "should return a geocode", (cbk) ->
        geo.geocode {test: 1}, (err, result) =>
          result.lng.should.equal 2
          result.lat.should.equal 1
          result.test.should.equal 1
          cbk()

      it "should not recalculate if lat and long are given", (cbk) ->
        geo.geocode {test: 2, lat: 1, lng: 2}, (err, result) ->
          should.not.exist err
          result.test.should.equal 2
          result.lat.should.equal 1
          result.lng.should.equal 2
          cbk()

      it "should throw an error if the service has an error", (cbk) ->
        geo.geocode {test: 'error'}, (err, result) ->
          should.exist err
          cbk()
