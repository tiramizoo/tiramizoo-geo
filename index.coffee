request = require "request"
querystring = require "querystring"
Seq = require "seq"

# accepts address with street, city, zip, country, state
# will return address with lat and lng set as floating point numbers
# or directly return the address if already given
exports.geocode = geocode = (address, callback) ->
  query = querystring.stringify(sensor: false, language: "de", address: address)
  mapsUrl = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/geocode/json?#{query}"
  request {url: mapsUrl, jar: false, json: true}, (error, response, body) ->
    if response?.statusCode isnt 200
      # TODO: proper error messages
      callback("Y U NO 200 GEOCODER?!?")
    else
      callback(error, body)

exports.directions = directions = (pickup, delivery, callback) ->
  query = querystring.stringify
    origin: "#{pickup.geometry.location.lat},#{pickup.geometry.location.lng}"
    destination: "#{delivery.geometry.location.lat},#{delivery.geometry.location.lng}"
    sensor: false
  mapsUrl = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
  request.get {url: mapsUrl, json: true, jar: false}, (error, response, body) ->
    if response?.statusCode isnt 200
      # TODO: proper error messages
      callback("Y U NO 200 DIRECTIONS?!?")
    else
      callback(error, body)

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

      drivingDistance = routes[0].legs[0].distance.value
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

    .catch(callback)
