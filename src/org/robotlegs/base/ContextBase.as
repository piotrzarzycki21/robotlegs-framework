/*
 * Copyright (c) 2009 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.robotlegs.base
{
	import org.apache.royale.events.Event;
	import org.apache.royale.events.IEventDispatcher;
	import org.apache.royale.events.EventDispatcher;
	
	import org.robotlegs.core.IContext;
	
	/**
	 * An abstract <code>IContext</code> implementation
	 */
	public class ContextBase implements IContext, IEventDispatcher
	{
		/**
		 * @private
		 */
		protected var _eventDispatcher:IEventDispatcher;
		
		//---------------------------------------------------------------------
		//  Constructor
		//---------------------------------------------------------------------
		
		/**
		 * Abstract Context Implementation
		 *
		 * <p>Extend this class to create a Framework or Application context</p>
		 */
		public function ContextBase()
		{
			_eventDispatcher = new EventDispatcher(this);
		}
		
		//---------------------------------------------------------------------
		//  API
		//---------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		public function get eventDispatcher():IEventDispatcher
		{
			return _eventDispatcher;
		}
		
		//---------------------------------------------------------------------
		//  EventDispatcher Boilerplate
		//---------------------------------------------------------------------

		/**
		 * @inheritDoc
		 */
		COMPILE::SWF
		public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
		{
			//	priority = flipPriority(type, priority);
			//@todo deal with priority event listeners
			eventDispatcher.addEventListener(type, listener, useCapture/*, priority, useWeakReference*/);
		}
		COMPILE::JS
		public function addEventListener(type:String, listener:Function, useCapture:Boolean = false,opt_handlerScope:Object = null):void
		{
			//	priority = flipPriority(type, priority);
			//@todo deal with priority event listeners
			eventDispatcher.addEventListener(type, listener, useCapture/*, priority, useWeakReference*/);
		}

		
		/**
		 * @private
		 */
		public function dispatchEvent(event:Event):Boolean
		{
 		    if(eventDispatcher.hasEventListener(event.type))
 		        return eventDispatcher.dispatchEvent(event);
 		 	return false;
		}
		
		/**
		 * @private
		 */
		public function hasEventListener(type:String):Boolean
		{
			return eventDispatcher.hasEventListener(type);
		}

		/**
		 * @inheritDoc
		 */
		COMPILE::SWF
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
		{
			eventDispatcher.removeEventListener(type, listener, useCapture);
		}

		/**
		 * @inheritDoc
		 */
		COMPILE::JS
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false,opt_handlerScope:Object = null):void
		{
			eventDispatcher.removeEventListener(type, listener, useCapture);
		}
		
		/**
		 * @private
		 */
		COMPILE::SWF
		public function willTrigger(type:String):Boolean
		{
			return eventDispatcher.willTrigger(type);
		}
	}
}
