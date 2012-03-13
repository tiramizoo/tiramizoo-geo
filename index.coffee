request = require 'request'
querystring = require 'querystring'
Seq = require 'seq'

# accepts address with street, city, zip, country, state
# will return address with lat and lng set as floating point numbers
# or directly return the address if already given
exports.geocode = (address, cbk) ->
  query = querystring.stringify(sensor: false, language: 'de', address: address)
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/geocode/json?#{query}"
  request {url: maps_url, jar: false, json: true}, (err, res, body) -> cbk(err, body)

exports.directions = (pickup, delivery, cbk) ->
  query = querystring.stringify
    origin: "#{pickup.geometry.lat},#{pickup.geometry.lng}"
    destination: "#{delivery.geometry.lat},#{delivery.geometry.lng}"
    sensor: false
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
  request.get {url: maps_url, json: true, jar: false}, (err, res, body) -> cbk(err, body)

# calculates a routing distance between two geo location points
exports.distance = (pickup, delivery, cbk) ->
  alreadyThrown = false

  Seq([pickup, delivery])
    .parEach_ (next, address) ->
      exports.geocode(address, next)
    .seq_ (next, pickups, deliveries) ->
      next("Internal Server Error") if pickups.length isnt 1
      next("Internal Server Error") if deliveries.length isnt 1

      pickup = pickups[0]
      delivery = deliveries[0]
      exports.directions(pickup, delivery, (err, directions) -> next(err, pickup, delivery, directions))
    .seq_ (next, pickup, delivery, directions) ->
      # TODO: proper error messages
      next("Internal Server Error") if directions.routes.length isnt 1

      zip = (address) ->
        address.address_components.filter (component) ->
          "postal_code" in comoponent.types

      pickup_zip = zip(pickup)[0]?.long_name
      delivery_zip = zip(delivery)[0]?.long_name

      result =
        pickup_address: pickup
        pickup_zip: pickup_zip
        delivery_address: delivery
        delivery_zip: delivery_zip
        distances:
          driving: directions.routes[0].legs[0].distance.value
          straight_line: 666 # TODO: calculate straight line distance

      next(null, result)
    .catch (err) ->
      # Guard against more than one call of cbk with err
      # which happens when geocode fails for both addresses.
      cbk err unless alreadyThrown
      alreadyThrown = true
