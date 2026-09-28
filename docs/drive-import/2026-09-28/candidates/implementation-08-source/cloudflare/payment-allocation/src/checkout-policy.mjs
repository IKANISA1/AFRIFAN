import {configure,uuid,club,exact,hash,AllocationError,amount} from './policy.mjs';
export {uuid,club,exact,hash};
export class CheckoutError extends Error {
  constructor(code='checkout_unavailable'){super(code);this.name='CheckoutError';this.code=code;}
}
export function requireCheckout(value,code='invalid_request'){if(!value)throw new CheckoutError(code);}
export function checkoutDatabase(env){
  requireCheckout(env.MEMBERSHIP_CHECKOUT_ENABLED==='true','checkout_disabled');
  try{return configure(env);}catch(error){throw new CheckoutError(error.code??'checkout_unavailable');}
}
export function prepareInput(input){
  try{exact(input,['requestId','clubId','userId','tier']);}catch{throw new CheckoutError('invalid_request');}
  requireCheckout(uuid(input.requestId)&&club(input.clubId)&&uuid(input.userId));
  requireCheckout(typeof input.tier==='string'&&input.tier.length<=64);
  const tier=input.tier.trim().toLowerCase();requireCheckout(/^[a-z0-9][a-z0-9_-]{0,31}$/.test(tier));
  return {...input,tier};
}
export function readInput(input){
  try{exact(input,['clubId','userId','orderId']);}catch{throw new CheckoutError('invalid_request');}
  requireCheckout(club(input.clubId)&&uuid(input.userId)&&uuid(input.orderId));return {...input};
}
export function validOffer(offer){
  requireCheckout(offer&&amount(offer.amount),'checkout_unavailable');
  requireCheckout(typeof offer.ussd_code==='string'&&offer.ussd_code.length<=128&&/^\*[0-9*]+#$/.test(offer.ussd_code),'invalid_payment_route');
  requireCheckout(offer.ussd_template.includes('{amount}')&&/\{(?:momo|recipient|code)\}/.test(offer.ussd_template),'invalid_payment_route');
  return offer;
}
export function checkoutError(error){
  if(error instanceof CheckoutError)return error;
  if(error instanceof AllocationError)return new CheckoutError(error.code);
  for(const code of ['checkout_permission_denied','checkout_rate_limited','checkout_offer_changed'])
    if(String(error?.message??'').includes(code))return new CheckoutError(code);
  return new CheckoutError('checkout_unavailable');
}
