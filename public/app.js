var app = new Vue({
    el: '#app',
    mounted: function(){
	console.log('foo');
    },
    router: (new VueRouter({
	routes: [
	    { path: '/',                redirect: '/screen' },
	    { path: '/screen',          component: httpVueLoader('components/screen.vue') },
	    { path: '/help',            component: httpVueLoader('components/help.vue') },
	    { path: '/queue',           component: httpVueLoader('components/queue.vue') },
	]})),
    data: {
	screen: {}
    }
})
