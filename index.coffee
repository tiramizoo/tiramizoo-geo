request = require "request"
querystring = require "querystring"
Seq = require "seq"

# accepts address with street, city, zip, country, state
# will return address with lat and lng set as floating point numbers
# or directly return the address if already given
geocode = (address, callback) ->
  query = querystring.stringify(sensor: false, language: "de", address: address)
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/geocode/json?#{query}"
  request {url: maps_url, jar: false, json: true}, (error, response, body) ->
    if response?.statusCode != 200
      callback(error, body)
    else
      # TODO: proper error messages
      callback("Y U NO 200?!?")

directions = (pickup, delivery, callback) ->
  query = querystring.stringify
    origin: "#{pickup.geometry.lat},#{pickup.geometry.lng}"
    destination: "#{delivery.geometry.lat},#{delivery.geometry.lng}"
    sensor: false
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
  request.get {url: maps_url, json: true, jar: false}, (error, response, body) ->
    if response?.statusCode != 200
      callback(error, body)
    else
      # TODO: proper error messages
      callback("Y U NO 200?!?")

# calculates a routing distance between two addresses
exports.distance = (pickup, delivery, callback) ->
  # WARNING: Seq parEach, parMap are fatally broken
  Seq()
    .seq_ (next) ->
      geocode pickup, (error, body) ->
        next(error, body?.results)

    .seq_ (next, pickups) ->
      geocode delivery, (error, body) ->
        next(error, pickups, body?.results)

    .seq_ (next, pickups, deliveries) ->
      # TODO: proper error messages
      next("Y U NO PICKUPS?!?") if pickups?.length isnt 1
      next("Y U NO DELIVERIES?!?") if deliveries?.length isnt 1

      pickup = pickups[0]
      delivery = deliveries[0]
      directions(pickup, delivery, (error, body) ->
        next(error, pickup, delivery, body?.routes))

    .seq_ (next, pickup, delivery, routes) ->
      # TODO: proper error messages
      next("Y U NO ROUTES?!?") if routes?.length isnt 1

      zip = (address) ->
        address.address_components.filter (component) ->
          "postal_code" in component.types

      driving_distance = routes[0].legs[0].distance.value
      pickup_zip = zip(pickup)[0]?.long_name
      delivery_zip = zip(delivery)[0]?.long_name

      callback null,
        pickup_address: pickup
        pickup_zip: pickup_zip
        delivery_address: delivery
        delivery_zip: delivery_zip
        distances:
          driving: driving_distance
          straight_line: 666 # TODO: calculate straight line distance

    .catch(callback)
