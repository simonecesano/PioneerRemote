<style>
.styled {
    border: 0;
    line-height: 2;
    padding: 0 20px;
    font-size: 1rem;
    text-align: center;
    color: #fff;
    border-radius: 0px;
    background-color: rgba(220, 0, 0, 1);

    grid-column: auto / span 2;
    height: 5em;
    border-radius: 6px;

}

@media screen and (min-width: 769px) {
    body {
	margin-left:  30%;
	margin-right: 30%;
    }
}


.styled:hover {
    background-color: rgba(255, 0, 0, 1);
}

.styled:active {
    box-shadow: inset -2px -2px 3px rgba(255, 255, 255, .6),
                inset 2px 2px 3px rgba(0, 0, 0, .6);
}

#items li { list-style-type: none; }

#screen {
    height: 50vh;
    margin: 6px;
}

table * { font-size: 8pt }

#paging div {
display:inline-block;text-align: center
}


.icon { font-size: 32pt }

#appspace {
    display: grid;
    grid-template-columns: repeat(6, 1fr);
    gap: 10px;
    grid-auto-rows: auto;
}

.block  {
    grid-column: 1 / 7;
    margin: 6px;
    display: grid;
    grid-template-columns: repeat(6, 1fr);
    gap: 10px;

}
#items { grid-column: 1 / 7 }

#items div { min-height: 18px; padding: 6px; }

.icon {
    grid-column: auto / span 1;
}
#pages {
    grid-column: auto / span 4;
    height: 16vw;
    line-height: 16vw;

}

button 

</style>
<template>
  <div id="appspace">
    <div class="block" id="screen" v-if="screen_type != '01'">
      <div id="items" style="">
	<h3 v-if="parseInt(header.screen) == 1 && header.title" style="padding:6px">{{ header.title }}</h3> 
	<div @click="pick(i)" v-for="(item, i) in screen">{{ item }}</div>
      </div>
    </div>
    <div class="block" id="paging" v-if="total > 1">
      <div v-if="first > 1" v-on:click="moveTo(-1)"  class="icon">&blacktriangleleft;</div>	
      <div class="icon" v-else>&nbsp;</div>
      <div v-if="true" id="pages">{{ first }}-{{ last }} of {{ total }}</div>
      <div v-else= id="pages">&nbsp;</div>
      <div v-if="total >= last+1" v-on:click="moveTo(1)" class="icon" >&blacktriangleright;</div>
      <div class="icon" v-else>&nbsp;</div>
    </div>
    <div class="block">
      <button class="favorite styled" @click="menuUp"
	      type="button">
	<img style="scale:150%" src="./icons/listing.svg">
      </button>
      <button class="favorite styled" @click="setInput('13FN')"
              type="button">
	<img style="scale:150%" src="./icons/radio.svg">
      </button>
      <button class="favorite styled" @click="setInput('10FN')"
              type="button">
	<img style="scale:150%" src="./icons/phone.svg">
      </button>
    </div>
    <div class="block">
      <table>
	<tbody>
	  <tr><td>source</td><td>{{ source }}</td></tr>
	  <tr><td>hierarchical</td><td>{{ header.hierarchical }}</td></tr>
	  <tr><td>top menu</td><td>{{ header.top_menu }}</td></tr>
	  <tr><td>return key</td><td>{{ header.return_key }}</td></tr>
	  <tr><td>title</td><td>{{ header.title }}</td></tr>
	</tbody>
      </table>
    </div>
  </div>
</template>
<script>
class Queue {
    constructor(frequency, ondone) {
	this.jobs = [];
	this.active = false;
	this.ondone = ondone;
	var c = this;

	setInterval(function() {
	    if (c.jobs.length == 0) { return };
	    if (c.active) { return };
	    
	    c.active = true;

	    var job = c.jobs.shift();

	    axios[job.method || 'get'](job.url, job.params)
		.then(d => {
		    c.ondone(d.data);
		    c.active = false;
		})
		.catch(e => {
		    c.active = false;		    
		    // console.log(e);
		    // throw(e);
		})
	}, frequency);
    }
    process(){

    }
    
    enqueue(job){
	if (job.immediate) {
	    delete job.immediate;
	    this.jobs.unshift(job);
	} else {
	    this.jobs.push(job);
	}
    }
}
    
module.exports = {
    data: function () {
	return {
	    lines: [],
	    
	    screen_type: undefined,

	    command: "",

	    lock: false,

	    first: 1, last: 1, total: 1,
	    hierarchical: undefined,
	    enter: undefined,
	    header: {},
	    socket: undefined,
	    source: undefined,
	}
    },
    mounted: function(){
	var c = this;

	c.queue = new Queue(1200, function(d){
	    c.lines = d;
	})
	// setInterval(function() {
	//     c.queue.enqueue({ url: '/screen' })
	// }, 2000);

	console.log(location.host);

	
	var onerror = function(e){ console.log(`connection error: ${e.message}`) }
	var onopen = function () {
	    this.send('hello')
	};
	var onmessage = function (msg) {
	    var data = JSON.parse(msg.data);
	    if (data.lines) {
		console.log(JSON.stringify(data.lines));
		c.lines = data.lines;
	    } else if (data.source) {
		c.source = data.source;
	    } else if (data.id) {
		console.log(data.id);
	    } else {
		console.log(data);
	    }
	};

	var ws = new WebSocket('ws://' + location.host + '/socket');
	ws.onopen    = onopen;
	ws.onerror   = onerror;
	ws.onmessage = onmessage;
	
	// var ws = new WebSocket('ws://' + location.host + '/socket');

	setInterval(function() {
	    if (ws.readyState != 1){
		console.log('opening new socket');
		ws = new WebSocket('ws://' + location.host + '/socket');
		ws.onopen    = onopen;
		ws.onerror   = onerror;
		ws.onmessage = onmessage;

		ws.send('hello');

		console.log(ws);
	    }
	}, 2000);

	// ws.onerror = function(e){
	//     console.log(`connection error: ${e.message}`);
	// }

	// ws.onopen = function () {
	//     this.send('hello');
	// };
	
	// ws.onmessage = function (msg) {
	//     var data = JSON.parse(msg.data);
	//     if (data.lines) {
	// 	c.lines = data.lines;
	//     } else {
	// 	c.source = data.source;
	//     }
	// };
    },
    watch: {
	lines: function(new_lines, old_lines){
	    this.handleChangedLines(new_lines);
	}
    },
    computed: {
	screen: function(){
	    return this.lines
		.filter(l => {
		    return l.match(/GEP.+?\".*\"/)
		    // return l.match(/GEP\".*\"/)
		})
		.map(l => l.replace(/.+?\"/, '"'))
		.map(l => l.replace(/^\"|\"$/g, ''))
		.map(l => l)
		.slice(0, 8)
	}
    },
    methods: {
	parseData: function(data){
	    var c = this;
	    c.lines = data;
	},
	handleChangedLines: function(data){
	    // var data = this.lines
	    var c = this;
	    if (data.filter(r => r.match(/^GDP/)).length) {
		var l = data.filter(r => r.match(/^GDP/)).shift();
		var m = l.match(/GDP(\d{5,5})(\d{5,5})(\d{5,5})/)
		m.shift();

		m = m.map(n => parseInt(n));

		c.first = m[0];
		c.last  = m[1];
		c.total = m[2];		
	    } else {
		c.first = c.last = c.total = 1
	    }
	    // GCPWWXY0Z0"SCREEN_NAME_LABEL", where:
	    // WW is a zero-padded value representing the screen type [00-99]
	    // X is the hierarchical list update flag [0/1]
	    // Y is the top menu key enable flag [0/1]
	    // Z is the return key enable flag [0/1]
	    // SCREEN_NAME_LABEL is the label for the current screen

	    if (data.filter(r => r.match(/^GCP/)).length) {
		var l = data.filter(r => r.match(/^GCP/)).shift();
		var m = l.match(/GCP(\d{2,2})(\d)(\d)0(\d)0(.+)/)
		c.header.screen = parseInt(m[1])
		c.header.hierarchical = m[2] ? true : false;
		c.header.top_menu     = m[3] ? true : false;
		c.header.return_key   = m[4] ? true : false;
		c.header.title   = m[5] ? JSON.parse(m[5]) : "";
	    } 
	},
	pick: function(i){
	    var c = this;

	    console.log(i, c.lines.filter(l => l.match()));
	    
	    var html = c.lines[i];

	    console.log(c.lines.filter(l => l.match(/GDP/)).shift())
	    
	    console.log(c.first, i, c.lines)
	    
	    var m = html.match(/GEP(\d\d)/);
	    
	    if (false) {
		console.log("not a menu item"); 
		return
	    } else {
		console.log('posting command')
		c.sendCommand({ command: 'GHP', item: parseInt(c.first + i) })
	    }
	},
	setInput: function(cmd){
	    console.log(cmd);
	    this.queue.enqueue({ method: 'post', url: '/input/' + cmd, immediate: true });
	},
	sendCommand: function(cmd){
	    var c = this;

	    cmd = cmd ? cmd : c.command;

	    console.log("sending command", cmd);
	    
	    if (typeof cmd == 'object') {
		c.queue.enqueue({ method: 'post', url: '/command', params: cmd, immediate: true });
	    } else if (cmd) {
		c.queue.enqueue({ method: 'post', url: '/command', params: { command: cmd }, immediate: true });
	    }
	},
	menuUp: function(){
	    var c = this;
	    if (c.source == "FN13") {
		console.log('ok')
		c.sendCommand('31PB')
	    }
	},
	moveTo: function(direction){
	    var c = this;
	    
	    console.log(direction, this.first, this.last, this.last - this.first)
	    var count = this.last - this.first;
	    var item = direction == 1 ? this.last + 1 : Math.max(1, this.first - 8);
	    
	    this.sendCommand({ command: 'GGP', item: item })
	}
    }
}
</script>
<style>
</style>
