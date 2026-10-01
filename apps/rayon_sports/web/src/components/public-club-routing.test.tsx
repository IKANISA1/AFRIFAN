import {cleanup, render, screen} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {supportedClubProfiles} from '@/lib/content';
import {parseFanAppDestinations, siteConfig} from '@/lib/config';
import type {ClubProfile} from '@/lib/types';
import PrivacyPage from '@/app/(site)/privacy/page';
import TermsPage from '@/app/(site)/terms/page';
import ShopPage from '@/app/(site)/shop/page';
import ProductPage from '@/app/(site)/shop/[productId]/page';
import MembershipPage from '@/app/(site)/membership/page';
import SupporterAppPage from '@/app/(site)/app/page';

const mocks=vi.hoisted(()=>({club:null as ClubProfile|null}));
vi.mock('@/lib/data/public',()=>({getClubProfile:async()=>mocks.club,getCmsContentBlock:async()=>null}));
vi.mock('@/lib/feature-page-guard',()=>({getFeaturePageGuard:async()=>null}));
vi.mock('@/lib/browser-portal-server',()=>({browserPortalConfig:async()=>null}));
vi.mock('next/headers',()=>({headers:async()=>new Headers({host:'selected-club.example'})}));
vi.mock('./shop-surfaces',()=>({ShopSurface:(props:{currencyCode:string;fanAppHref:string;hasExternalAppUrl:boolean})=><p data-testid="shop-props">{JSON.stringify(props)}</p>,ShopProductSurface:(props:{currencyCode:string})=><p data-testid="product-props">{JSON.stringify(props)}</p>}));
vi.mock('./membership-surface',()=>({MembershipSurface:(props:{clubShortName:string;fanAppHref:string})=><p data-testid="membership-props">{JSON.stringify(props)}</p>}));
const original={destinations:siteConfig.fanAppDestinations,url:siteConfig.fanAppUrl};
beforeEach(()=>{siteConfig.fanAppDestinations=parseFanAppDestinations('{}');siteConfig.fanAppUrl='https://rayon-only.example';});
afterEach(()=>{cleanup();siteConfig.fanAppDestinations=original.destinations;siteConfig.fanAppUrl=original.url;});

describe('actual per-club public route callers',()=>{
 it.each(supportedClubProfiles)('keeps $shortName identity in privacy and terms without another club in the fallback',async club=>{
   mocks.club=club; const privacy=render(await PrivacyPage());
   expect(screen.getByText(`${club.clubName} supports guest and authenticated supporter journeys. The information processed depends on the features a supporter chooses to use.`)).toBeVisible();
   if(club.id!==24) expect(screen.queryByText(/Gikundiro|Rayon Sports|Blue Wall/)).not.toBeInTheDocument();
   privacy.unmount();render(await TermsPage());
   expect(screen.getByRole('heading',{name:`Using ${club.clubName}`})).toBeVisible();
   if(club.id!==24) expect(screen.queryByText(/Gikundiro|Rayon Sports|Blue Wall/)).not.toBeInTheDocument();
 });
 it.each(supportedClubProfiles)('passes $currencyCode and scoped app availability through actual shop/member routes',async club=>{
   mocks.club=club;render(await ShopPage());
   expect(JSON.parse(screen.getByTestId('shop-props').textContent!)).toMatchObject({clubId:club.id,currencyCode:club.currencyCode,hasExternalAppUrl:club.id===24,fanAppHref:club.id===24?'https://rayon-only.example/':'/app'});
   cleanup();render(await ProductPage({params:Promise.resolve({productId:'shirt'}),searchParams:Promise.resolve({})}));
   expect(JSON.parse(screen.getByTestId('product-props').textContent!)).toMatchObject({clubId:club.id,currencyCode:club.currencyCode});
   cleanup();render(await MembershipPage());
   expect(JSON.parse(screen.getByTestId('membership-props').textContent!)).toMatchObject({clubShortName:club.shortName,clubId:club.id,currencyCode:club.currencyCode,hasExternalAppUrl:club.id===24});
 });
 it('renders verified platform choice and truthful unavailable states on the club app destination',async()=>{
   mocks.club=supportedClubProfiles.find(club=>club.id===26)!;
   siteConfig.fanAppDestinations=parseFanAppDestinations('{"nkana_zm":{"ios":"https://ios.example","android":"https://android.example"}}');
   render(await SupporterAppPage());
   expect(screen.getByRole('link',{name:'Open iOS app listing'})).toHaveAttribute('href','https://ios.example/');
   expect(screen.getByRole('link',{name:'Open Android app listing'})).toHaveAttribute('href','https://android.example/');
   expect(screen.getByRole('link',{name:'Open member area'})).toHaveAttribute('href','/membership');
   expect(screen.getByText('Supporter web app: no release link is available yet.')).toBeVisible();
   expect(screen.queryByText(/Rayon|Gikundiro/)).not.toBeInTheDocument();
 });
 it.each(supportedClubProfiles)('does not invent native store links for $shortName',async club=>{
   mocks.club=club;siteConfig.fanAppUrl='';render(await SupporterAppPage());
   expect(screen.queryByRole('link',{name:/app listing/})).not.toBeInTheDocument();
   expect(screen.getByText('iOS: no release link is available yet.')).toBeVisible();
   expect(screen.getByText('Android: no release link is available yet.')).toBeVisible();
 });
});
