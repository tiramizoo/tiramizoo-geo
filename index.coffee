request = require "request"
querystring = require "querystring"
Seq = require "seq"

# Internal: Geocode an address using Google's Geocoder
#
# address - the String with an address to geocode
# callback - function to pass the result to
#   (google.maps.GeocoderResult objects)

exports.geocode = geocode = (address, callback) ->
  query = querystring.stringify(sensor: false, language: "de", address: address)
  mapsUrl = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/geocode/json?#{query}"
  request {url: mapsUrl, jar: false, json: true}, (error, response, body) ->
    if response?.statusCode isnt 200
      # TODO: proper error messages
      callback("Y U NO 200 GEOCODER?!?")
    else
      callback(error, body)

# Internal: Geocode an address using Google's DirectionsService
#
# from - from google.maps.GeocoderResult object
# to - to google.maps.GeocoderResult object
# callback - function to pass the result to
#   (google.maps.DirectionsResult)

exports.directions = directions = (from, to, callback) ->
  query = querystring.stringify
    origin: "#{from.geometry.location.lat},#{from.geometry.location.lng}"
    destination: "#{to.geometry.location.lat},#{to.geometry.location.lng}"
    sensor: false
  mapsUrl = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
  request.get {url: mapsUrl, json: true, jar: false}, (error, response, body) ->
    if response?.statusCode isnt 200
      # TODO: proper error messages
      callback("Y U NO 200 DIRECTIONS?!?")
    else
      callback(error, body)

# Internal: Calculate straight line distance using Haversine formula
#
# from - to google.maps.GeocoderResult object
# to - to google.maps.GeocoderResult object
# callback - function to pass the result to
#
# Returns Number

exports.haversine = haversine = (from, to, radius = 6371) ->
  lat1 = from.geometry.location.lat
  lng1 = from.geometry.location.lng

  lat2 = to.geometry.location.lat
  lng2 = to.geometry.location.lng

  dlat = (lat2 - lat1) * Math.PI / 180
  dlng = (lng2 - lng1) * Math.PI / 180
  lat1 = lat1 * Math.PI / 180
  lat2 = lat2 * Math.PI / 180

  a = Math.sin(dlat / 2) * Math.sin(dlat / 2) + Math.sin(dlng / 2) * Math.sin(dlng / 2) * Math.cos(lat1) * Math.cos(lat2)
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  radius * c

# Public: Calculate distance between two addresses
#
# pickup - String with pickup address
# delivery - String with delivery address
# callback - function to pass the result to

exports.distance = (pickup, delivery, callback) ->
  hackAlreadyCalled = false

  # WARNING: Seq parEach, parMap are fatally broken
  Seq()
    .par_ (next) ->
      geocode pickup, (error, body) ->
        next(error, body?.results)

    .par_ (next) ->
      geocode delivery, (error, body) ->
        next(error, body?.results)

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

      # TODO: take the shortest route instead of the first one
      drivingDistance = routes[0].legs[0].distance.value / 1000
      straightLineDistance = haversine(pickup, delivery)

      pickupZip = zip(pickup)[0]?.long_name
      deliveryZip = zip(delivery)[0]?.long_name

      callback null,
        pickup_address: pickup
        pickup_zip: pickupZip
        delivery_address: delivery
        delivery_zip: deliveryZip
        distances:
          driving: drivingDistance
          straight_line: straightLineDistance

    .catch (err) ->
      callback(err) unless hackAlreadyCalled
      hackAlreadyCalled = true
