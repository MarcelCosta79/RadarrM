#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>> /config/logs/striplog.txt 2>&1
####################################################################
# Credits for the code.                                            #
#  https://github.com/theskyisthelimit/ubtuntumkvtoolnix   
#  https://github.com/SimpsomRJ/docker-radarr
#                                                                  #
# I've just made some tweaks.                                      #
####################################################################

###############  PushOver API  #####################################
APP_TOKEN="YOUR_TOKEN_HERE"
USER_TOKEN="YOUR_TOKEN_HERE"
####################################################################

###############  Telegram API  #####################################
TOKEN="YOUR_TOKEN_HERE"
CHAT_ID="YOUR_TOKEN_HERE"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
info="%3Ca%20href%3D%22https%3A%2F%2Fwww.imdb.com%2Ftitle%2F$radarr_movie_imdbid%22%3E%3Cb%3E$radarr_movie_title%3C%2Fb%3E%3C%2Fa%3E%20%0ALibrary:%20FullHD%0AUpgrade%3A%20$radarr_isupgrade%0A$radarr_moviefile_scenename"
####################################################################


fpath="$radarr_moviefile_path"
file=$(basename "$fpath")
ss=$(dirname "$fpath")
cd "$ss"

echo
date
echo "Processing $file"
DETAILS=$(mkvmerge -J "$file")
#echo "$DETAILS"
mkvmerge -i "$file"

########################################################## FIND & SEEK ###########################################################################################
#Track wanted audio files
audio=$(echo "$DETAILS" | jq '[.tracks[] | select (.type=="audio" and (.properties.language | test("eng|por|kor|jpn|und")) and (.properties.track_name | test("Commentary|Director"; "i") | not)) | select (.codec | test("TruHV|AC9|DTZ"; "i") | not) |  .id] | map(tostring) | join(",")' | cut -f2 -d\")
#Total wanted audio files
audiocount=$(echo $audio | tr "," "\n" | wc -l)
echo "1: Found audio tracks $audio ($audiocount) to keep"

#Track wanted subtitle files
subs=$(echo "$DETAILS" | jq '[.tracks[] | select (.type=="subtitles" and (.codec | test("PGSy|ASSy|SRTy"; "i") | not) and (.properties.language | test("eng|por|und"))) | .id] | map(tostring) | join(",")' | cut -f2 -d\")
#Total wanted subtitle files
subscount=$(echo $subs | tr "," "\n" | wc -l)
echo "2: Found subtitle tracks $subs ($subscount) to keep"
##################################################################################################################################################################

######################################################### SOME MATHS #############################################################################################
#Total number of audios and subtitles tracks	
totalaudio=$(echo "$DETAILS" | jq '.tracks[] | select (.type=="audio") | .id' | wc -l)
totalsubs=$(echo "$DETAILS" | jq '.tracks[] | select (.type=="subtitles") | .id' | wc -l)

#Total files minus wanted files 
diffaudio=$(expr $totalaudio - $audiocount)
diffsubs=$(expr $totalsubs - $subscount)		
		
##################################################################################################################################################################		

    echo "3: setting parameters"

    if [ -z "$subs" ] # If: String Empty. Purge subtitles. Else: keep wanted subs.
    then
      subs="-S"
    else
      subs="-s $subs"
    fi
    		
	if [ -z "$audio" ]
			then
				 mkvmerge $subs -o "${file%.mkv}".edited.mkv "$file"; #keep Orignal audio
				 mv "${file%.mkv}".edited.mkv "$file"
				 echo "7: Foreign movie processed"
				 # mv "$1" /media/Trash/;
					if [ $TOKEN!= "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						curl -s -X POST $URL -d parse_mode="html" -d chat_id=$CHAT_ID -d text="$info%0A Foreign movie processed" > /dev/null 2>&1 &
					elif [ $APP_TOKEN != "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						wget https://api.pushover.net/1/messages.json --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$file - Foreign movie processed.&title=RadarrM" -qO- > /dev/null 2>&1 &
					fi
			else
				if [ $diffaudio -gt 0 -o $diffsubs -gt 0 ] # Any is greater than 0
				then
					audio="-a $audio";
					mkvmerge $subs $audio -o "${file%.mkv}".edited.mkv "$file";
					mv "${file%.mkv}".edited.mkv "$file"
					echo "4: Unwanted audio or subtitles found and removed!"		
					# mv "$1" /media/Trash/;
					if [ $TOKEN != "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						curl -s -X POST $URL -d parse_mode="html" -d chat_id=$CHAT_ID -d text="$info%0AAudio or Subtitle removed" > /dev/null 2>&1 &
					elif [ $APP_TOKEN != "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						wget https://api.pushover.net/1/messages.json --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$file - Audio or Subtitle removed.&title=RadarrM" -qO- > /dev/null 2>&1 &
					fi
			
				else
					echo "4: Nothing found to remove. Will exit script now."
					if [ $TOKEN != "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						curl -s -X POST $URL -d parse_mode="html" -d chat_id=$CHAT_ID -d text="$info%0ANothing found to remove." > /dev/null 2>&1 &
					elif [ $APP_TOKEN != "YOUR_TOKEN_HERE" ] #Don't modify
					then 
						wget https://api.pushover.net/1/messages.json --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$file - Nothing found to remove.&title=RadarrM" -qO- > /dev/null 2>&1 &
					fi
				fi				
	fi
  
exit
