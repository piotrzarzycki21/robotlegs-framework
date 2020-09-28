/*
 * Copyright (c) 2009 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.robotlegs.base
{
import org.apache.royale.reflection.TypeDefinition;
import org.apache.royale.reflection.utils.getMembersWithNameMatch;

COMPILE::SWF{
		import flash.utils.Dictionary;
	}


	import org.apache.royale.events.Event;
	import org.apache.royale.events.IEventDispatcher;

	import org.apache.royale.reflection.describeType;
	
	import org.robotlegs.core.ICommandMap;
	import org.robotlegs.core.IInjector;
	import org.robotlegs.core.IReflector;
	
	/**
	 * An abstract <code>ICommandMap</code> implementation
	 */
	public class CommandMap implements ICommandMap
	{
		/**
		 * The <code>IEventDispatcher</code> to listen to
		 */
		protected var eventDispatcher:IEventDispatcher;
		
		/**
		 * The <code>IInjector</code> to inject with
		 */
		protected var injector:IInjector;
		
		/**
		 * The <code>IReflector</code> to reflect with
		 */
		protected var reflector:IReflector;
		
		/**
		 * Internal
		 *
		 * TODO: This needs to be documented
		 */
		protected var eventTypeMap:Object;
		
		/**
		 * Internal
		 *
		 * Collection of command classes that have been verified to implement an <code>execute</code> method
		 */
		COMPILE::SWF
		private const verifiedCommandClasses:Dictionary = new Dictionary();

		COMPILE::JS
		private const verifiedCommandClasses:Map = new Map();

		//this could perhaps be implemented with a simple Array:
		COMPILE::SWF
		private const detainedCommands:Dictionary = new Dictionary();

		COMPILE::JS
		private const detainedCommands:Map = new Map();




		//---------------------------------------------------------------------
		//  Constructor
		//---------------------------------------------------------------------
		
		/**
		 * Creates a new <code>CommandMap</code> object
		 *
		 * @param eventDispatcher The <code>IEventDispatcher</code> to listen to
		 * @param injector An <code>IInjector</code> to use for this context
		 * @param reflector An <code>IReflector</code> to use for this context
		 */
		public function CommandMap(eventDispatcher:IEventDispatcher, injector:IInjector, reflector:IReflector)
		{
			this.eventDispatcher = eventDispatcher;
			this.injector = injector;
			this.reflector = reflector;
			this.eventTypeMap = {};
			//the following were switched to declaration/assignment:
			/*this.verifiedCommandClasses = {};
			this.detainedCommands = {};*/
		}
		
		//---------------------------------------------------------------------
		//  API
		//---------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		public function mapEvent(eventType:String, commandClass:Class, eventClass:Class = null, oneshot:Boolean = false):void
		{
			verifyCommandClass(commandClass);
			eventClass = eventClass || Event;
			
			var eventClassMap:Object = eventTypeMap[eventType] ||= {};
				
			var callbacksByCommandClass:Object = eventClassMap[eventClass] ||= {};
				
			if (callbacksByCommandClass[commandClass] != null)
			{
				throw new ContextError(ContextError.E_COMMANDMAP_OVR + ' - eventType (' + eventType + ') and Command (' + commandClass + ')');
			}
			var callback:Function = function(event:Event):void
			{
				routeEventToCommand(event, commandClass, oneshot, eventClass);
			};
			eventDispatcher.addEventListener(eventType, callback, false/*, 0, true*/);
			callbacksByCommandClass[commandClass] = callback;
		}
		
		/**
		 * @inheritDoc
		 */
		public function unmapEvent(eventType:String, commandClass:Class, eventClass:Class = null):void
		{
			var eventClassMap:Object = eventTypeMap[eventType];
			if (eventClassMap == null) return;
			
			var callbacksByCommandClass:Object = eventClassMap[eventClass || Event];
			if (callbacksByCommandClass == null) return;
			
			var callback:Function = callbacksByCommandClass[commandClass];
			if (callback == null) return;
			
			eventDispatcher.removeEventListener(eventType, callback, false);
			delete callbacksByCommandClass[commandClass];
		}
		
		/**
		 * @inheritDoc
		 */
		public function unmapEvents():void
		{
			for (var eventType:String in eventTypeMap)
			{
				var eventClassMap:Object = eventTypeMap[eventType];
				for each (var callbacksByCommandClass:Object in eventClassMap)
				{
					for each ( var callback:Function in callbacksByCommandClass)
					{
						eventDispatcher.removeEventListener(eventType, callback, false);
					}
				}
			}
			eventTypeMap = {};
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasEventCommand(eventType:String, commandClass:Class, eventClass:Class = null):Boolean
		{
			var eventClassMap:Object = eventTypeMap[eventType];
			if (eventClassMap == null) return false;
			
			var callbacksByCommandClass:Object = eventClassMap[eventClass || Event];
			if (callbacksByCommandClass == null) return false;
			
			return callbacksByCommandClass[commandClass] != null;
		}
		
		/**
		 * @inheritDoc
		 */
		public function execute(commandClass:Class, payload:Object = null, payloadClass:Class = null, named:String = ''):void
		{
			verifyCommandClass(commandClass);
			
			if (payload != null || payloadClass != null)
			{
				payloadClass ||= reflector.getClass(payload);

				if (payload is Event && payloadClass != Event)
					injector.mapValue(Event, payload);

				injector.mapValue(payloadClass, payload, named);
			}
			
			var command:Object = injector.instantiate(commandClass);
			
			if (payload !== null || payloadClass != null)
			{
				if (payload is Event && payloadClass != Event)
					injector.unmap(Event);

				injector.unmap(payloadClass, named);
			}
			
			command.execute();
		}
		
		/**
		 * @inheritDoc
		 */
		public function detain(command:Object):void
		{
			detainedCommands[command] = true;
		}
		
		/**
		 * @inheritDoc
		 */
		public function release(command:Object):void
		{
			if (detainedCommands[command])
				delete detainedCommands[command];
		}
		
		//---------------------------------------------------------------------
		//  Internal
		//---------------------------------------------------------------------
		
		/**
		 * @throws org.robotlegs.base::ContextError 
		 */
		protected function verifyCommandClass(commandClass:Class):void
		{
			var verfied:Boolean;
			COMPILE::SWF{
				verfied = verifiedCommandClasses[commandClass]
			}
			COMPILE::JS{
				verfied = verifiedCommandClasses.get(commandClass)
			}

			if (!verfied)
			{
				var typeDef:TypeDefinition = describeType(commandClass);

				var executeExists:Boolean = getMembersWithNameMatch(typeDef.methods,'execute').length > 0;

				COMPILE::SWF{
					verifiedCommandClasses[commandClass] = executeExists
				}
				COMPILE::JS{
					verifiedCommandClasses.set(commandClass, executeExists)
				}

				if (!executeExists)
					throw new ContextError(ContextError.E_COMMANDMAP_NOIMPL + ' - ' + commandClass);
			}
		}
		
		/**
		 * Event Handler
		 *
		 * @param event The <code>Event</code>
		 * @param commandClass The Class to construct and execute
		 * @param oneshot Should this command mapping be removed after execution?
         * @return <code>true</code> if the event was routed to a Command and the Command was executed,
         *         <code>false</code> otherwise
		 */
		protected function routeEventToCommand(event:Event, commandClass:Class, oneshot:Boolean, originalEventClass:Class):Boolean
		{
			if (!(event is originalEventClass)) return false;
			
			execute(commandClass, event);
			
			if (oneshot) unmapEvent(event.type, commandClass, originalEventClass);
			
			return true;
		}
	
	}
}
