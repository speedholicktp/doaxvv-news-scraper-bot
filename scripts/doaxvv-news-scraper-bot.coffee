# Description
#   A DOAXVV official site scraper for Discord.
#
# Configuration:
#   HUBOT_DISCORD_TOKEN
#   HUBOT_DISCORD_STATUS_MSG
#   HUBOT_DISCORD_WEBHOOK_URL
#   (Heroku only)  HUBOT_HEROKU_KEEPALIVE_URL
#   (Heroku only)  HUBOT_HEROKU_KEEPALIVE_INTERVAL
#   (Heroku only)  HUBOT_HEROKU_WAKEUP_TIME
#   (Heroku only)  HUBOT_HEROKU_SLEEP_TIME
#   (Heroku only)  Heroku scheduler to execute the following for waking up BOT:
#                    curl ${HUBOT_HEROKU_KEEPALIVE_URL}heroku/keepalive
# Commands:
#   check ... Force check now
#
# Notes:
#   Runs periodically. The interval is determined by .doaxvv-news-scraper-bot.json.
#
# Author:
#    ktp <unofficial.doaxvv.bot@gmail.com>

fs = require 'fs'
crypto = require 'crypto'
client = require 'cheerio-httpcli'
request = require 'request'
cronJob = require('cron').CronJob

# Get env vars.
config =
  webhookUrl: process.env.HUBOT_DISCORD_WEBHOOK_URL

module.exports = (robot) ->
  #
  # Functions
  #
  loadJSON = ->
    try
      json = fs.readFileSync('./.doaxvv-news-scraper-bot.json', 'utf8')
      return JSON.parse(json)
    catch err
      return err

  md5hex = (src)->
    md5hash = crypto.createHash('md5')
    md5hash.update(src, 'binary')
    return md5hash.digest('hex')

  saveHex = (title, str) ->
    try
      fs.writeFileSync('./tmp/'+ md5hex(title),md5hex(str))
    catch err
      robot.logger.error err
      return err

  checkUpdate = (title, str) ->
    try
      hash = fs.readFileSync('./tmp/'+ md5hex(title)).toString()
      newHash = md5hex(str)
      if (hash is newHash) or (hash is '')
        return false
      else
        return true
    catch err
      robot.logger.error err
      return false

  sendToDiscord = (title, url) ->
    data = JSON.stringify({
      content: title + "の更新: " + url
    })
    robot.http(config.webhookUrl)
      .header('Content-Type', 'application/json')
       .post(data) (err, res, body) ->
       #

  checkPages = (client, pages, json, opt_pointer) ->
    this.pointer = opt_pointer || 0
    page = pages[pointer]
    client.fetch(page.url)
    .then (result) ->
      robot.logger.info page.name
      if page.exclude_class?
        result.$('.' + page.exclude_class).remove()
      res = checkUpdate(page.url, result.$('ul li').text())
      if res is true
          robot.logger.info page.name + ' is updated'
          sendToDiscord(page.name, page.url)
      saveHex(page.url, result.$('ul li').text())
      pointer += 1
      if pointer == pages.length
        return
      checkPages(client, pages, json, pointer)
    .catch (err) ->
      robot.logger.error err

  #
  # Execute
  #

  json = loadJSON()

  robot.respond /check$/i, (msg) ->
    checkPages(client, json.pages)
    msg.reply('')

  doaxvvNewsCron = new cronJob({
    cronTime: json.cron_time
    onTick: ->
      checkPages(client, json.pages)
      .then ->
        robot.logger.info 'finish'
      .catch (err) ->
        robot.logger.error err
      .finally ->
        msg.reply('')
    start: true
  })
