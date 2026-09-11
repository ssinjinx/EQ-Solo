import React from 'react';
import {createRoot} from 'react-dom/client';
import Home from '../app/page';
import '../app/globals.css';
import './test.css';
createRoot(document.getElementById('root')!).render(<><div className="testBanner">TEST SERVER · Separate test collection · Close this window to return to EQ</div><Home/></>);
