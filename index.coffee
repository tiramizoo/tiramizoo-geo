request = require 'request'
Hash = require 'hashish'
querystring = require 'querystring'

# accepts address with street, city, zip, country, state
# will return address with lat and lng set as floating point numbers
# or directly return the address if already given
exports.geocode = (address, cbk) ->
  # parse lat and long to float
  lat = parseFloat address.lat
  lng = parseFloat address.lng

  # directly accept the values and return the address
  # if both are valid numbers
  unless isNaN(lat) or isNaN(lng)
    address.lat = lat
    address.lng = lng
    return cbk null, address

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
  query = querystring.stringify {origin: from, destination: to}
  maps_url = "#{process.env.GOOGLE_MAPS_API_URL || 'http://maps.googleapis.com'}/maps/api/directions/json?#{query}"
  request.get {url: maps_url, json: true, jar: false}, (err, res, body) ->
    if !err and (body?.routes?.length > 0)
      cbk null, {distance: parseFloat body.routes[0].legs[0].distance.value}
    else
      cbk err || 'Internal Server Error'

