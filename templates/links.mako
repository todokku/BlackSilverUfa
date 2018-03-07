<%inherit file="include/base.mako" />
<%namespace file="include/elements.mako" name="el" />
<%!

import json
import urllib
import hashlib
import datetime

def md5file(f_path, block_size=2**20):
    md5 = hashlib.md5()
    with open(f_path, 'rb') as f:
        while True:
            data = f.read(block_size)
            if not data:
                break
            md5.update(data)
    return md5.hexdigest()

%>

<%block name="head">
<title>${game['name']} | ${config['title']}</title>

<!-- jQuery -->
<script src="//code.jquery.com/jquery-3.2.1.min.js"></script>
<!-- Plyr (https://github.com/sampotts/plyr) -->
<link rel="stylesheet" href="//cdn.plyr.io/2.0.18/plyr.css">
<script src="//cdn.plyr.io/2.0.18/plyr.js"></script>
<!-- Subtitles Octopus (https://github.com/Dador/JavascriptSubtitlesOctopus) -->
<script src="/static/js/subtitles-octopus.js"></script>

<script src="/static/js/player.js?hash=${md5file('static/js/player.js')}"></script>

<style>
.main-content {
  padding: 2rem;
  max-width: 72rem;
}
</style>
</%block>

<%block name="content">
<%
  def sec(t):
    return sum(int(x) * 60 ** i for i,x in enumerate(reversed(t.split(":"))))

  def sec_with_offset(stream, t):
    if stream.get('offset'):
      return sec(t) - sec(stream['offset'])
    else:
      return sec(t)

  def sec_to_timecode(t):
    return str(datetime.timedelta(seconds=t))

  # TODO: Export this function into separate file
  def player_compatible(stream):
    for i in ['youtube', 'vk', 'direct']:
       if i in stream:
           return True
    return False

  def mpv_file(stream):
    if stream.get('youtube'):
      return 'ytdl://' + stream['youtube']
    elif stream.get('vk'):
      return 'https://api.thedrhax.pw/vk/video/' + stream['vk'] + '\?redirect'
    elif stream.get('direct'):
      return stream['direct']

  def mpv_args(stream):
    result = '--sub-file=chats/v{}.ass '.format(stream['twitch'])

    if stream.get('offset'):
      result += '--sub-delay=-{} '.format(sec(stream['offset']))

    return result.strip()

%>

<%def name="timecode_link(id, stream, timecode)">\
<% seconds = sec_with_offset(stream, timecode) %>\
<a onclick="players[${id}].seek(${seconds})">${sec_to_timecode(seconds)}</a>\
</%def>

<%def name="timecode_list(id, stream)">\
<%
  signs = [sec_with_offset(stream, timecode[0]) > 0
           for timecode in stream['timecodes']]
%>\
% if True in signs:
  <li>Таймкоды:</li>
  <ul>
  % for timecode in stream['timecodes']:
    % if sec_with_offset(stream, timecode[0]) > 0:
    <li>${timecode_link(id, stream, timecode[0])} - ${timecode[1]}</li>
    % endif
  % endfor
  </ul>
% endif
</%def>

<%def name="source_link(stream, text=u'Запись')">\
% if stream.get('youtube'):
  <li>${text} (YouTube): <a href="https://www.youtube.com/watch?v=${stream['youtube']}">${stream['youtube']}</a></li>
% elif stream.get('vk'):
  <li>${text} (ВКонтакте): <a href="https://vk.com/video${stream['vk']}">${stream['vk']}</a></li>
% elif stream.get('direct'):
  <li>${text}: <a href="${stream['direct']}">прямая ссылка</a></li>
% else:
  <li>${text}: отсутствует</li>
% endif
</%def>

<%def name="player(id, stream, text=u'Открыть плеер')">
<p>
  <%
  player_data_dict = stream.copy()

  for param in ['name', 'note', 'timecodes', 'segment']:
    player_data_dict.pop(param, None)

  player_data = json.dumps(player_data_dict).replace('"', '&quot;')

  %>\
  <a onclick="return spawnPlayer(${id}, JSON.parse('${player_data}'))" id="button-${id}">
    <b>▶ ${text}</b>
  </a>
</p>

<p class="player-wrapper" id="player-wrapper-${id}" style="margin-top: 32px; display: none"></p>

<script>
if (window.location.hash) {
  var id = window.location.hash.replace('#', '');
  if (id == "${id}" || id == "${stream['twitch']}") {
    spawnPlayer(${id}, JSON.parse('${json.dumps(player_data_dict)}'));
    document.title = "${stream['name']} | ${game['name']} | ${config['title']}";
  }
}
</script>
</%def>

<%def name="gen_stream(id, stream)">
<h2 id="${stream['twitch']}">
  <a id="${id}" href="#${stream['twitch']}">${stream['name']}</a>
</h2>

<ul>
% if stream.get('note'):
  <li>Примечание: ${stream['note']}</li>
% endif
  <li>Ссылки:</li>
  <ul>
    <li>Twitch: <a href="https://www.twitch.tv/videos/${stream['twitch']}">${stream['twitch']}</a></li>
    <li>Субтитры: <a href="../chats/v${stream['twitch']}.ass">v${stream['twitch']}.ass</a></li>
    ${source_link(stream)}
  </ul>
% if stream.get('offset'):
  <li>Эта запись смещена на ${stream['offset']} от начала стрима</li>
% endif
% if stream.get('timecodes'):
  ${timecode_list(id, stream)}
% endif
% if stream.get('start'):
  <li>Игра начинается с ${timecode_link(id, stream, stream['start'])}</li>
% endif
% if stream.get('end'):
  <li>Запись заканчивается в ${timecode_link(id, stream, stream['end'])}</li>
% endif
</ul>

% if player_compatible(stream):
${player(id, stream)}
% endif

<h4>Команда для просмотра стрима в проигрывателе MPV</h4>

<%el:code_block>\
% if player_compatible(stream):
mpv ${mpv_args(stream)} ${mpv_file(stream)}
% else:
streamlink -p "mpv ${mpv_args(stream)}" --player-passthrough hls twitch.tv/videos/${stream['twitch']} best
% endif
</%el:code_block>

<hr>
</%def>

<h1><a href="/">Архив</a> → ${game['name']}</h1>
<% id = 0 %> \
% for stream in game['streams']:
${gen_stream(id, stream)}
<% id += 1 %> \
% endfor

<p>Приведённые команды нужно выполнить, находясь в корне ветки gh-pages данного Git репозитория и подготовив все нужные программы по <a href="../tutorials/watch-online.md">этой</a> инструкции.</p>

<p>Быстрый старт:</p>
<ul>
  <li><%el:code>git clone https://github.com/TheDrHax/BlackSilverUfa.git</%el:code></li>
  <li><%el:code>cd BlackSilverUfa</%el:code></li>
  <li><%el:code>git checkout gh-pages</%el:code></li>
  <li>Команда, приведённая выше</li>
</ul>
</%block>
