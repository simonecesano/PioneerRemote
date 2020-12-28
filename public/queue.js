class Queue {
    constructor(frequency, ondone) {
	this.jobs = [];
	setInterval(function() {
	    var job = this.jobs.shift();
	    axios[job.method || 'get'](job.url, job.params)
		.then(d => {
		    ondone(d.data);
		})
		.catch(e => {
		    console.log(e);
		})
	}, frequency);
    }
    enqueue(job){
	this.jobs.push(job);
    }
}

