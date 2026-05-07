/** Metillium Trigger Framework from https://github.com/lfreeland/Saleforce-Trigger-Framework */
trigger LeadTrigger on Lead (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
  new mtf.TriggerHandler().run();
}
