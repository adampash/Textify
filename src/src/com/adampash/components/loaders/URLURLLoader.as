package com.adampash.components.loaders
{

import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.events.HTTPStatusEvent;

public dynamic class URLURLLoader extends URLLoader
{

    private var _req:URLRequest;

    public function URLURLLoader( request:flash.net.URLRequest = null ):void
    {   super( request );
        _req = request;
    }

    public override function load( request:flash.net.URLRequest ):void
    {   _req = request;
        super.load( request );
    }

    public function get urlRequest( ):URLRequest
    {   return _req;
    }

}

}