request = require 'request'
Hash = require 'hashish'
querystring = require 'querystring'
Seq = require 'seq'

# accepts address with street, city, zip, country, state
# will return address with lat and lng set as floating point numbers
# or directly return the address if already given
exports.geocode = (address, cbk) ->
  query = querystring.stringify {sensor: false, language: 'de', address: Hash(address).values.join(', ')}
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/geocode/json?#{query}"
  request {url: maps_url, jar: false, json: true}, (err, res, body) ->
    if !err and (body?.results?.length > 0)
      address.lat = body.results[0].geometry.location.lat
      address.lng = body.results[0].geometry.location.lng
      cbk null, address
    else
      cbk err || 'No geocoding results'

# calculates a routing distance between two geo location points
exports.routeDistance = (from, to, cbk) ->
  Seq([from, to])
    .parEach_ (next, address) ->
      if address.lat? and address.lng?
        next null, address
      else
        exports.geocode address, next
    .seq_ (next) ->
      query = querystring.stringify {origin: "#{from.lat},#{from.lng}", destination: "#{to.lat},#{to.lng}", sensor: false}
      maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
      request.get {url: maps_url, json: true, jar: false}, (err, res, body) ->
        if !err and (body?.routes?.length > 0)
          cbk null, {distance: parseFloat body.routes[0].legs[0].distance.value}
        else
          cbk err || 'Internal Server Error'
