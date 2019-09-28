class LinebotController < ApplicationController
    require 'line/bot' #gem 'line-bot-api'
    require 'open-uri'
    require 'kconv'
    require 'rexml/document'
    #callbackアクションのCSRFトークン認証を無効
    protect_from_forgery :except => [:callback]
    
    def callback
        body = request.body.read
        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
            head :bad_request
        end
        events = client.parse_events_from(body)
        events.each { |event|
            case event
            #メッセージが送られてきたときの対応(機能１)
            when Line::Bot::Event::Message
                case event.type
                #ユーザーからテキスト形式のメッセージが送られてきた場合
                when Line::Bot::Event::MessageType::Text
                    #event.message['text']:ユーザーから送られてきたメッセージ
                    input = event.message['text']
                    url = "https://www.drk7.jp/weather/xml/28.xml"
                    xml = open( url ).read.toutf8
                    doc = REXML::Document.new(xml)
                    xpath = 'weatherforecast/pref/area[2]/'
                    #当日朝のメッセージの送信の下限値は２０％としているが、明日明後日雨が降るかどうかの下限値を３０％としている
                    min_per = 30
                    case input
                    #明日orあしたというワードが含まれる場合
                    when /.*(明日|あした).*/
                        #info[2]:明日の天気
                        per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
                        per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
                        per18to24 = dec.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
                        if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                            push = "明日の天気だよね。\n明日は雨が降りそうだよ。\n今のところ降水確率はこんな感じだよ。\n6時~12時　#{per06to12}%\n12時~18時　#{per12to18}%\n18時~24時　#{per18to24}%\nまた明日の朝の最新の天気予報を教えてあげるからね！"
                        else
                            push = "明日の天気？\n明日は雨が降らない予報だよ。\nまた明日の朝の最新の天気予報を教えてあげるね！"
                        end
                    when /.*(明後日|あさって).*/
                        per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
                        per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
                        per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text                                                if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                        if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                            push = "明後日の天気だよね。\n明後日は雨が降りそうだよ。\n今のところ降水確率はこんな感じだよ。\n6時~12時　#{per06to12}%\n12時~18時　#{per12to18}%\n18時~24時　#{per18to24}%\n当日の朝にまた教えてあげるね！"
                        else
                            push = "明後日の天気？\n気が早いね！\n明後日は雨が降らない予報だよ。\nまた当日の予報を教えてあげるね！"
                        end
                    when /.*(こんにちは|おはよう|こんばんわ).*/
                        push = "こんにちは\n今日があなたにとって良い1日になりますように(^^)"
                    else
                        per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]'].text
                        per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]'].text
                        per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]'].text
                        if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
                            word = [
                                "雨だけど元気出していこうね！",
                                "雨に負けずにファイト！",
                                "雨だけどあなたの明るさでみんなを元気にしてあげて！"].sample
                            push = "今日の天気？\n今日は雨が降りそうだから傘を持って行ったほうがいいよ。\n6時~12時　#{per06to12}%\n12時~18時　#{per12to18}%\n18時~24時　#{per18to24}\n#{word}"
                        else
                            word = [
                                "天気もいいから一駅歩いてみるのはどう？",
                                "素晴らしい1日になりますように(^^)",
                                "雨が降ったらごめんね"].sample
                            push = "今日の天気？\n今日は雨が降らないみたいだよ！\n#{word}"
                        end
                    end
                    # when Line::Bot::Event::MessageType::Location
                    #     #位置入力がされた場合
                    #     latitude = event.message['latitude'] #緯度
                    #     longitude = event.message['longitude'] #経度
                        
                    #テキスト以外が送られてきた場合
                    else
                        push = "テキスト以外わからないよ〜"
                end
                    
                message = {
                    type: 'text',
                    text: push
                }
                client.reply_message(event['replyToken'], message)
                #LINEお友達追加された場合
            when Line::Bot::Event::Follow
                # 登録したユーザーのidをユーザーテーブルに格納する
                line_id = event['source']['userId']
                User.create(line_id: line_id)
                #LINEお友達解除された場合
            when Line::Bot::Event::Unfollow
                line_id = event['source']['userId']
                User.find_by(line_id: line_id).destoy
            end
        }
        head :ok
    end
    
    private
    def client
        @client ||= Line::Bot::Client.new { |config|
            config.channel_secret = ENV["LINE_CHANNNEL_SECRET"]
            config.channel_token = ENV["LINE_CHANNNEL_TOKEN"]
        }
    end
end
